resource "aws_security_group" "lb_sg" {

  # General
  name                   = "lb-sg"
  vpc_id                 = var.core_vpc.id
  description            = "..."
  revoke_rules_on_delete = true

  # Accept from anywhere on 443 - Listen Port
  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # Accept from Nginx (Running on Port 80) 
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "TCP"
    cidr_blocks = [
      var.core_vpc.cidr_block
    ]
  }

  # LB is internet facing; send traffic to anywhere
  egress {
    from_port        = 0
    to_port          = 65535
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    name = "lb-sg"
  }

}