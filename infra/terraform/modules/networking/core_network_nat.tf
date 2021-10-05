# NAT for the DB AZ of the 
resource "aws_nat_gateway" "nat-1f" {
  allocation_id = aws_eip.nat_1f.id
  subnet_id     = aws_subnet.us-east-1f-public.id

  tags = {
    Name = "gateway-nat-1f"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [
    aws_internet_gateway.core-igw
  ]
}
