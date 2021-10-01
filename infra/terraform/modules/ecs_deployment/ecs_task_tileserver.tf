resource "aws_ecs_task_definition" "tileserver-api" {

  # General
  family = "tileserver-api"

  # Execution Role - Just use the default ECSTaskExecutionRole
  execution_role_arn = data.aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = data.aws_iam_role.ecs_task_execution_role.arn

  requires_compatibilities = [
    "EC2"
  ]

  # Resource Allocation - Assumes we're using a r6 medium w. 1024 CPU shares + 8GB memory
  cpu    = 1024 # 1 CPU 
  memory = "8192" # 8 GB Memory - Don't plan for all of it!

  # Networking/Security
  network_mode = "bridge"

  # Container definition
  container_definitions = jsonencode(
    [

      # Task 1 - Tileserver - Golang
      {

        # Basics
        "name" : "tileserver",
        "image" : "${data.aws_ecr_image.tileserver-api-img.registry_id}.dkr.ecr.${var.default_region}.amazonaws.com/${data.aws_ecr_image.tileserver-api-img.repository_name}:${var.image_tag}",
        "essential" : true,

        # Resource Requirements
        "cpu" : 256,
        "memory" : 128,
        "memoryReservation" : 512,


        # Start/Stop Timeouts on the Container...
        "startTimeout" : 60,
        "stopTimeout" : 60,

        # Environment
        "environment" : [
          {
            "name" : "API__RETURN_LIMIT_BYTES",
            "value" : "131072"
          },
          {
            "name" : "PG__HOST",
            "value" : "${var.postgres_host_internal_ip}"
          },
          {
            "name" : "PG__PASSWORD",
            "value" : "${var.osm_pg__worker_pwd}" // "averysecurepassword" // [TODO]: Change Application to Use Secrets Manager...
          },
          {
            "name" : "PG__PORT",
            "value" : "5432"
          },
          {
            "name" : "PG__DATABASE",
            "value" : "geospatial_core"
          },
          {
            "name" : "PG__USER",
            "value" : "osm_reader"
          },
          {
            "name" : "PG__SSL_MODE",
            "value" : "disable"
          },
          {
            "name" : "REDIS__HOST",
            "value" : "tilecache"
          },
          {
            "name" : "REDIS__PORT",
            "value" : "6379"
          },
          {
            "name" : "REDIS__USE_CACHE",
            "value" : "true"
          },
          {
            "name" : "REDIS__CACHE_LIMIT_BYTES",
            "value" : "131072"
          },
          {
            "name" : "REDIS__CACHE_TTL",
            "value" : "600"
          },
          {
            "name" : "REDIS__PURGE_ON_START",
            "value" : "0"
          },
          {
            "name" : "AWS_XRAY__HOST",
            "value" : "xray-daemon:2000"
          },
          {
            "name" : "AWS_XRAY__SVC_VERSION",
            "value" : "3.3.3"
          }
        ],

        # Logging Params
        "logConfiguration" : {
          "logDriver" : "awslogs",
          "options" : {
            "awslogs-group" : aws_cloudwatch_log_group.tileserver-api.name,
            "awslogs-region" : "${var.default_region}",
            "awslogs-stream-prefix" : "ecs"
          }
        },

        "links" : [
          "tilecache:tilecache",
          "xray-daemon:xray-daemon",
        ]

        # Health Check
        "healthCheck" : {
          "command" : ["CMD-SHELL", "curl -XGET http://localhost:2151/health/ || exit 1"],
          "interval" : 30,
          "retries" : 4,
          "timeout" : 5
        },

        # Port Mappings - Expose 2151 to Serve Requests
        "portMappings" : [
          {
            "containerPort" : 2151,
            "hostPort" : 2151,
            "protocol" : "tcp"
          }
        ]

      },

      # Task #2 - Tile Cache - Redis
      {
        # Basics
        "name" : "tilecache",
        "image" : "${data.aws_ecr_image.tileserver-cache-img.registry_id}.dkr.ecr.${var.default_region}.amazonaws.com/${data.aws_ecr_image.tileserver-cache-img.repository_name}:${var.image_tag}",
        "essential" : true,

        # Resource Requirements
        "cpu" : 128,
        "memory": 256,
        "memoryReservation" : 6144,

        # Start/Stop Timeouts on the Container...
        "startTimeout" : 60,
        "stopTimeout" : 60,

        # Health Check
        "healthCheck" : {
          "command" : ["CMD-SHELL", "redis-cli ping || exit 1"],
          "interval" : 30,
          "retries" : 4,
          "timeout" : 5
        },

        # Logging Params
        "logConfiguration" : {
          "logDriver" : "awslogs",
          "options" : {
            "awslogs-group" : aws_cloudwatch_log_group.tileserver-api.name,
            "awslogs-region" : "${var.default_region}",
            "awslogs-stream-prefix" : "ecs"
          }
        },

        # Port Mappings - Expose 2151 to Serve Requests
      },

      # Task #3 - Nginx
      {
       "name": "nginx",
       "image": "${data.aws_ecr_image.tileserver-cache-img.registry_id}.dkr.ecr.${var.default_region}.amazonaws.com/${data.aws_ecr_image.nginx-img.repository_name}:${var.image_tag}",

      "cpu" : 128,
      "memory": 128,
      "memoryReservation" : 128,
       
       "essential": true,

       "portMappings": [
         {
           "containerPort": 80,
           "hostPort" : 80,
           "protocol": "tcp"
         }
       ],
      
      "healthCheck" : {
          "command" : ["CMD-SHELL", "lsof -i TCP:80 || exit 1"],
          "interval" : 30,
          "retries" : 4,
          "timeout" : 5
      },

       "logConfiguration" : {
          "logDriver" : "awslogs",
          "options" : {
            "awslogs-group" : aws_cloudwatch_log_group.tileserver-api.name,
            "awslogs-region" : "${var.default_region}",
            "awslogs-stream-prefix" : "ecs"
          }
        },

       "links": [
         "tileserver:tileserver"
       ]
     },
      # Task #4 - AWS XRay Agent
      {
        "name" : "xray-daemon",
        "image" : "${data.aws_ecr_image.tileserver-cache-img.registry_id}.dkr.ecr.${var.default_region}.amazonaws.com/${data.aws_ecr_image.xray-agent-img.repository_name}:${var.image_tag}",
        "essential" : false,

        "cpu" : 128,
        "memory": 64,
        "memoryReservation" : 128,

        "environment" : [
          {
            "name" : "AWS_REGION",
            "value" : "${var.default_region}"
          },
        ],

        "healthCheck" : {
          "command" : ["CMD-SHELL", "lsof -i UDP:2000 || exit 1"],
          "interval" : 30,
          "retries" : 4,
          "timeout" : 5
      },

        # TCP Port 2000 too! - Just to make sure the golang app gets it...
        "portMappings" : [
          {
            "hostPort" : 2000,
            "containerPort" : 2000,
            "protocol" : "udp"
          },
          {
            "hostPort" : 2000,
            "containerPort" : 2000,
            "protocol" : "tcp"
          }
        ]

        "logConfiguration" : {
          "logDriver" : "awslogs",
          "options" : {
            "awslogs-group" : aws_cloudwatch_log_group.tileserver-api.name,
            "awslogs-region" : "${var.default_region}",
            "awslogs-stream-prefix" : "ecs"
          }
        }

      }

    ]

  )

}