# Create a load balancer that does SSL termination and routes traffic to Port 80 of the container
# instances.


# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb
resource "aws_lb" "tileserver_api_lb" {

  # General
  name               = "tileserver-api-lb"
  load_balancer_type = "application"
  internal           = false
  idle_timeout       = 5

  # Security + Access - Allow all Traffic 
  security_groups = [
    aws_security_group.lb_sg.id
  ]

  subnets = [
    var.public_subnet_1.id, var.public_subnet_2.id
  ]

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    name = "tileserver-lb"
  }
}


# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group
resource "aws_lb_target_group" "tileserver_target_grp" {
  name        = "tileserver-target-grp"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.core_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 3
    interval            = 60
    matcher             = "200"
    path                = "/health/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 30
    unhealthy_threshold = 2
  }

}

# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener
resource "aws_lb_listener" "alb_https_listener_rule" {

  load_balancer_arn = aws_lb.tileserver_api_lb.arn
  port              = "443"
  protocol          = "HTTPS"

  # SSL Cert
  ssl_policy      = "ELBSecurityPolicy-2016-08"
  certificate_arn = data.aws_acm_certificate.maphub_api_lb_acm_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tileserver_target_grp.arn
  }

  tags = {
    name = "https-listener"
  }

}