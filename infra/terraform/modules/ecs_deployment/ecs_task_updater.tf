resource "aws_ecs_task_definition" "osm-update-daemon" {

  # General
  family = "osm-update-daemon"

  # Execution Role - Just use the default ECSTaskExecutionRole
  execution_role_arn = data.aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = data.aws_iam_role.ecs_task_execution_role.arn

  requires_compatibilities = [
    "EC2"
  ]

  # Resource Allocation - Assumes we're using a r6 medium w. 1024 CPU shares + 8GB memory
  cpu    = 256   # 1/4th of a CPU - literally just a `wget`...consider scheduling or running on lambda...
  memory = "256" # So little, just for tge OSM wget...

  # Networking/Security
  network_mode = "bridge"

  # Container definition
  container_definitions = jsonencode(
    [
      {
        "name" : "osm-updater",
        "image" : "${data.aws_ecr_image.osm-updater-img.registry_id}.dkr.ecr.${var.default_region}.amazonaws.com/${data.aws_ecr_image.osm-updater-img.repository_name}:${var.image_tag}",
        "essential" : true,

        # Resource Requirements
        "cpu" : 256,
        "memory" : 256,
        "memoryReservation" : 64,

        # Start/Stop Timeouts on the Container...
        "startTimeout" : 60,
        "stopTimeout" : 60,

        # Environment
        "environment" : [
          {
            "name" : "PG__HOST",
            "value" : "${var.postgres_host_internal_ip}"
          },
          {
            "name" : "PG__PASSWORD",
            "value" : "${var.osm_pg__worker_pwd}"
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
            "value" : "osm_worker"
          },
          {
            "name" : "OSM__UPDATE_SERVER",
            "value" : "https://planet.openstreetmap.org/replication/hour/"
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
        }

      }
    ]
  )

}