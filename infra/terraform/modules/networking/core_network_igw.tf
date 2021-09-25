
# Internet gaetway for the core geospatial VPC
# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway
resource "aws_internet_gateway" "core-igw" {

  vpc_id = aws_vpc.geospatial-core.id

  tags = {
    Name = "geospatial-vpc-igw"
    Module = "Core Network"
  }

}