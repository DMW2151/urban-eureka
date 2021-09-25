# Create public and private subnets in two AZs in the same region...

# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet
resource "aws_subnet" "us-east-1f-public" {

  # Basic
  vpc_id                  = aws_vpc.geospatial-core.id
  cidr_block              = "10.0.0.0/18"
  availability_zone       = "us-east-1f"
  map_public_ip_on_launch = true

  tags = {
    Name = "us-east-1f-public"
    Module = "Tileserver Core Networking"
  }
}

resource "aws_subnet" "us-east-1d-public" {

  # Basic
  vpc_id                  = aws_vpc.geospatial-core.id
  cidr_block              = "10.0.64.0/18"
  availability_zone       = "us-east-1d"
  map_public_ip_on_launch = true

  tags = {
    Name = "us-east-1d-public"
    Module = "Tileserver Core Networking"
  }
}

resource "aws_subnet" "us-east-1f-private" {

  # Basic
  vpc_id            = aws_vpc.geospatial-core.id
  cidr_block        = "10.0.128.0/18"
  availability_zone = "us-east-1f"
  map_public_ip_on_launch = false

  tags = {
    Name = "us-east-1f-private"
    Module = "Tileserver Core Networking"
  }
}

resource "aws_subnet" "us-east-1d-private" {

  # Basic
  vpc_id            = aws_vpc.geospatial-core.id
  cidr_block        = "10.0.192.0/18"
  availability_zone = "us-east-1d"
  map_public_ip_on_launch = false

  tags = {
    Name = "us-east-1d-private"
    Module = "Tileserver Core Networking"
  }
}
