# ECS - Define service for ECS Tile API cluster
# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service 
resource "aws_ecs_service" "tileserver-api" {

  # General
  name            = "tileserver-api"
  cluster         = aws_ecs_cluster.backend_ecs_cluster.arn
  task_definition = aws_ecs_task_definition.tileserver-api.arn

  # Deployment Params
  launch_type                        = "EC2"
  scheduling_strategy                = "DAEMON"
  enable_ecs_managed_tags            = true
  propagate_tags                     = "SERVICE"
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  health_check_grace_period_seconds  = 30
  enable_execute_command             = true
  force_new_deployment               = true


  # Set traffic to go to NGINX - should be the only open port on 
  # the container machines
  load_balancer {
    target_group_arn = aws_lb_target_group.tileserver_target_grp.arn
    container_name   = "nginx"
    container_port   = 80
  }

  
  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [us-east-1f, us-east-1d]"
  }

  tags = {
    name = "tileserver-api-service"
  }
}
