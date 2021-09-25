resource "aws_ecs_task_definition" "tileserver-api" {

  # General
  family = "tileserver-api"

  # Execution Role - Just use the default ECSTaskExecutionRole
  execution_role_arn = data.aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = data.aws_iam_role.ecs_task_execution_role.arn

  requires_compatibilities = [
    "EC2"
  ]

  # Resource Asllocation
  cpu    = 512
  memory = "2048"

  # Networking/Security
  network_mode = "bridge"

  # Container definition
  container_definitions = jsonencode(
    [

      # Service 1 - Tileserver - Golang
      {

        # Basics
        "name" : "tileserver",
        "image" : "${data.aws_ecr_image.tileserver-api-img.registry_id}.dkr.ecr.${var.default_region}.amazonaws.com/${data.aws_ecr_image.tileserver-api-img.repository_name}:${var.image_tag}",
        "essential" : true,

        # Resource Requirements
        "cpu" : 0,
        "memory" : 128,

        # Start/Stop Timeouts on the Container...
        "startTimeout" : 60,
        "stopTimeout" : 60,

        # Environment
        "environment" : [
          {
            "name" : "PG_HOST",
            "value" : "${var.postgres_host_internal_ip}"
          },
          {
            "name" : "PGPASSWORD",
            "value" : "${var.osm_pg__worker_pwd}"
          },
          {
            "name" : "REDIS_HOST",
            "value" : "tilecache"
          }
        ],

        # Health Check
        # "healthCheck" : {
        #   "command" : ["CMD-SHELL", "redis-cli ping || exit 1"],
        #   "interval" : 30,
        #   "retries" : 4,
        #   "timeout" : 5
        # },

        # Logging Params
        "logConfiguration" : {
          "logDriver" : "awslogs",
          "options" : {
            "awslogs-group" : aws_cloudwatch_log_group.tileserver-api.name,
            "awslogs-region" : "${var.default_region}",
            "awslogs-stream-prefix" : "ecs"
          }
        },
        
        "links": [
          "tilecache:tilecache"
        ]


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
        "cpu" : 0,
        "memory" : 128,

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
      }

    ]

  )

}