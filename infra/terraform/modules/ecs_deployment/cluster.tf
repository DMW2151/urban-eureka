resource "aws_ecs_cluster" "backend_ecs_cluster" {

  # General
  name = "dev-backend-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      logging    = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.tileserver-cluster.name
      }
    }
  }

  tags = {
    environment = "development"
  }

}
