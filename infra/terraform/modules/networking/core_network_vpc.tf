# Create Core VPC for the tileserver ECS Cluster and all other services for the site...
# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
resource "aws_vpc" "geospatial-core" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = false

  tags = {
    Name   = "geospatial-core"
    Module = "Tileserver Core Networking"
  }
}