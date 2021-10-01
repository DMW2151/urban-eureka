resource "aws_security_group" "lb_sg" {

  # General
  name                   = "lb-sg"
  vpc_id                 = var.core_vpc.id
  description            = "..."
  revoke_rules_on_delete = true

  # Ingress/Egress Rules
  #   - In from 0.0.0.0 on 443, only load balancer to be listening on 443
  #   - Out to the sensor API on 5000 
  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # Application Port - Within VPC - For app [TODO: rm]
  ingress {
    from_port = 2151
    to_port   = 2151
    protocol  = "TCP"
    cidr_blocks = [
      var.core_vpc.cidr_block
    ]
  }

  # For Nginx
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "TCP"
    cidr_blocks = [
      var.core_vpc.cidr_block
    ]
  }

  # Send to Anywhere...
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    name = "lb-sg"
  }

}

resource "aws_security_group" "allow_sg" {

  name                   = "allow-lb-sg"
  vpc_id                 = var.core_vpc.id
  description            = "..."
  revoke_rules_on_delete = true

  # Send to Anywhere...
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    name = "lb-sg"
  }

}