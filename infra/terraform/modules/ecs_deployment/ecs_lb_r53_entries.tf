# Need to associate the new load balancers with existing certs; these have been created + registered beforehand
# only thing variable is the new CNAME entry to load balancer w. api.maphub.dev...

data "aws_acm_certificate" "maphub_api_lb_acm_cert" {
  domain      = "api.maphub.dev"
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}


data "aws_route53_zone" "primary" {
  name         = "maphub.dev"
  private_zone = false
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