# Elastic IPs for the build, these IPs are to be associated with the NAT gateways between 
# each AZ's public and private subnets

# Resource: Elastic IP
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip
resource "aws_eip" "nat_1f" {
  vpc        = true
  depends_on = [aws_internet_gateway.core-igw] # Whole Object - NOT just ID

  tags = {
    Name   = "geospatial-vpc-nat-1f"
    Module = "Core Network"
  }
}
