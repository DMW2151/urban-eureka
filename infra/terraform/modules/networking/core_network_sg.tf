# Security group for the load balancer

# AWS Security Group - A very permissive group that allows any resource in the VPC to
# communicate with any other, provided the ports are configured properly.
# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
resource "aws_security_group" "vpc_all_traffic_sg" {

  # General
  name                   = "vpc_all_traffic_sg"
  vpc_id                 = aws_vpc.geospatial-core.id
  description            = "Allows all access (ingress + egress) from within the VPC on all ports"
  revoke_rules_on_delete = true
  
  # Ingress/Egress Rules
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
      aws_vpc.geospatial-core.cidr_block
    ]
    self = true
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
      aws_vpc.geospatial-core.cidr_block
    ]
    self = true
  }

  tags = {
    Name = "vpc_all_traffic"
    Module = "Tileserver Core Networking"
  }

}

# AWS Security Group - A group that allows SSH access from the IP of the developer into any resource
# running SSH (provided they have the key, of course!)
# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
resource "aws_security_group" "ssh_from_deployer" {

  # General
  name                   = "deployer-sg"
  vpc_id                 = aws_vpc.geospatial-core.id
  description            = "Allows SSH access from the IP of the terraform user, most likely myself..."
  revoke_rules_on_delete = true

  # Ingress/Egress Rules
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "TCP"
    cidr_blocks = [
      var.deployer_ip
    ]
  }

  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = [
      var.deployer_ip
    ]
  }

  tags = {
    name = "deployer_to_vpc_traffic"
    Module = "Tileserver Core Networking"
  }

}