output "core-vpc" {
  value = aws_vpc.geospatial-core
}

output "subn-us-east-1f-public" {
  value = aws_subnet.us-east-1f-public
}

output "subn-us-east-1f-private" {
  value = aws_subnet.us-east-1f-private
}

output "subn-us-east-1d-public" {
  value = aws_subnet.us-east-1d-public
}

output "subn-us-east-1d-private" {
  value = aws_subnet.us-east-1d-private
}

output "vpc-all-traffic-sg" {
  value = aws_security_group.vpc_all_traffic_sg
}

output "deployer-ssh-to-vpc-sg" {
  value = aws_security_group.ssh_from_deployer
}
