# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_configuration
resource "aws_launch_configuration" "ecs_launch_config" {
  image_id                    = "ami-0c92c94c2ecbd7d9c"
  iam_instance_profile        = aws_iam_instance_profile.ecs_agent.name
  associate_public_ip_address = false

  security_groups = [
    aws_security_group.ecs_sg.id,
    var.vpc_all_traffic_sg.id,
  ]

  user_data     = filebase64("./../modules/ecs_deployment/userdata/worker_userdata.sh")
  instance_type = "c6g.large"
  key_name      = "public-jump-1"

  spot_price = "0.04"

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_autoscaling_group" "asg" {

  name = "ecs-tiles-api-asg-c6"

  vpc_zone_identifier = [
    var.public_subnet_1.id,
    var.public_subnet_2.id
  ]

  launch_configuration = aws_launch_configuration.ecs_launch_config.name

  desired_capacity          = 2
  min_size                  = 1
  max_size                  = 3
  health_check_grace_period = 300
  health_check_type         = "EC2"
}