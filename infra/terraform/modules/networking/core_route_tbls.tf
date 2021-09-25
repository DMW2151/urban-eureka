# Create a Route Table -> Public Route Table -> Enable Internet Connectivity
resource "aws_route_table" "main" {
  
  # Basic
  vpc_id = aws_vpc.geospatial-core.id

  # Routes
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.core-igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.core-igw.id
  }

  tags = {
    Name = "tileserver-main"
    Module = "Tileserver Core Networking"
  }
}


resource "aws_route_table" "public" {

  # Basic
  vpc_id = aws_vpc.geospatial-core.id

  # Routes
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.core-igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.core-igw.id
  }

  tags = {
    Name = "tileserver-subn-public"
    Module = "Tileserver Core Networking"
  }
}

resource "aws_route_table" "private-1f" {

  # Basic
  vpc_id = aws_vpc.geospatial-core.id

  # Routes
  # All Traffic Not from xxx.xxx.xxx.xxx/16 Uses this...
  route { 
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-1f.id
  }

  tags = {
    Name = "tileserver-subn-private-1f"
    Module = "Tileserver Core Networking"
  }
}

resource "aws_route_table" "private-1d" {

  # Basic
  vpc_id = aws_vpc.geospatial-core.id

  # Routes
  # All Traffic Not from xxx.xxx.xxx.xxx/16 Uses this...
  route { 
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-1d.id
  }

  tags = {
    Name = "tileserver-subn-private-1d"
    Module = "Tileserver Core Networking"
  }
}


# Main Association for the VPC - Not sure if this is needed, but want to be explicit 
# about assignment...
# Association - VPC
resource "aws_main_route_table_association" "asc-main-vpc" {
  vpc_id         = aws_vpc.geospatial-core.id
  route_table_id = aws_route_table.main.id

  tags = {
    Module = "Tileserver Core Networking"
  }
}

# All route table associations, links public 1d & 1f with a `public` table allowing 
# acccess to the internet via IGW and links private 1d and 1f to their respective 
# private route tables, routing traffic from the internet through the NAT -> IGW -> WWW

# Association Public 1F
resource "aws_route_table_association" "asc-public-subnet-use-1f" {
  subnet_id      = aws_subnet.us-east-1f-public.id
  route_table_id = aws_route_table.public.id

  tags = {
    Module = "Tileserver Core Networking"
  }
}

# Association Private 1F
resource "aws_route_table_association" "asc-private-subnet-use-1f" {
  subnet_id      = aws_subnet.us-east-1f-private.id
  route_table_id = aws_route_table.private-1f.id
  
  tags = {
    Module = "Tileserver Core Networking"
  }

}

# Association Public 1D
resource "aws_route_table_association" "asc-public-subnet-use-1d" {
  subnet_id      = aws_subnet.us-east-1d-public.id
  route_table_id = aws_route_table.public.id

  tags = {
    Module = "Tileserver Core Networking"
  }
}

# Association Private 1D
resource "aws_route_table_association" "asc-private-subnet-use-1d" {
  subnet_id      = aws_subnet.us-east-1d-private.id
  route_table_id = aws_route_table.private-1d.id

  tags = {
    Module = "Tileserver Core Networking"
  }
}
