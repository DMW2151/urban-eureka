data "aws_acm_certificate" "maphub_api_lb_acm_cert" {
  domain      = "api.maphub.dev"
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}


data "aws_route53_zone" "primary" {
  name         = "maphub.dev"
  private_zone = false
}


resource "aws_lb" "tileserver_api_lb" {

  # General
  name               = "tileserver-api-lb"
  load_balancer_type = "application"
  internal           = false
  idle_timeout       = 5

  # Security + Access
  security_groups = [
    aws_security_group.lb_sg.id,
    var.vpc_all_traffic_sg.id
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


resource "aws_route53_record" "maphub_api" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "api.maphub.dev"
  type    = "CNAME"
  ttl     = "300"
  records = [
    aws_lb.tileserver_api_lb.dns_name
  ]
}

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