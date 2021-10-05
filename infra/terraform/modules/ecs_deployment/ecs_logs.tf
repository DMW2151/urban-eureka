# Define a group for the logs, split into lambda, ECS application, and ECS

# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group
resource "aws_cloudwatch_log_group" "tileserver-api" {

  # General
  name              = "/ecs/tileserver-api"
  retention_in_days = 90

  tags = {
    name = "tileserver-api-log-group"
  }
}

# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group
resource "aws_cloudwatch_log_group" "osm-update" {

  # General
  name              = "/ecs/osm-update"
  retention_in_days = 90

  tags = {
    name = "osm-update-log-group"
  }
}

# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group
resource "aws_cloudwatch_log_group" "tileserver-cluster" {

  # General
  name              = "/ecs/tileserver-api-cluster"
  retention_in_days = 90

  tags = {
    name = "tileserver-api-log-group"
  }
}