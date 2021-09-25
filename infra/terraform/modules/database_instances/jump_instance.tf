# Just a Jump Server...
# Launch a small instance in the public subnet of Core VPC for administrative tasks

# Define the jump server instance in-line...
# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance
resource "aws_instance" "jump-1" {

  # Basics
  # [NOTE] this isn't any old ubuntu or AWS Linux instance, this instance include the ECS utilities 
  # pre-baked, leads to smaller user-data script...
  ami           = "ami-0c92c94c2ecbd7d9c"
  instance_type = "t4g.nano"

  # Security + Networking
  #
  # [NOTE] Treatment for keys is atypical of terraform. No way to access a key as a data resource
  # just identify by name and EC2 checks if the key exists in your account!
  subnet_id                   = var.jump_subnet.id
  availability_zone           = var.jump_subnet.availability_zone
  associate_public_ip_address = true
  key_name                    = "public-jump-1"
  vpc_security_group_ids      = [var.deployer_sg.id, var.vpc_all_traffic_sg.id]

  user_data            = data.template_file.jump-user-data.template
  iam_instance_profile = aws_iam_instance_profile.jump_profile.name

  # Tags
  tags = {
    Name   = "Public Jump - 1"
    Module = "Database Instances"
  }

}
