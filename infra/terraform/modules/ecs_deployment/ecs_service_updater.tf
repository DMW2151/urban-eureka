resource "aws_ecs_service" "osm-update-daemon" {

  # General
  name            = "osm-update-daemon"
  cluster         = aws_ecs_cluster.backend_ecs_cluster.arn
  task_definition = aws_ecs_task_definition.osm-update-daemon.arn

  # Deployment Params
  launch_type                        = "EC2"
  scheduling_strategy                = "REPLICA"
  enable_ecs_managed_tags            = true
  propagate_tags                     = "SERVICE"
  deployment_maximum_percent         = 200
  desired_count                      = 1
  deployment_minimum_healthy_percent = 100
  enable_execute_command             = true
  force_new_deployment               = true

  # Set traffic to go to NGINX - should be the only open port on 
  # the container machines  
  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [us-east-1f, us-east-1d]"
  }

  tags = {
    name = "osm-update-daemon"
  }
}