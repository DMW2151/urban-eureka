variable "core_vpc" {
  description = "Core VPC of the deployment"
  type = object({
    id         = string
    arn        = string
    cidr_block = string
  })
}

variable "account_id" {
  description = "Account ID of the caller"
  type        = string
}

variable "db_subnet" {
  description = "Private Subnet for the DB (may be called private_subnet in other places!)"
  type = object({
    id                   = string
    arn                  = string
    availability_zone_id = string
    availability_zone    = string
  })
}

variable "jump_subnet" {
  description = "Public Subnet for Jump instances and APIs"
  type = object({
    id                   = string
    arn                  = string
    availability_zone_id = string
    availability_zone    = string
  })
}

variable "vpc_all_traffic_sg" {
  description = "Default decurity group to apply for intra-VPC traffic"
  type = object({
    name = string
    arn  = string
    id   = string
  })
}

variable "deployer_sg" {
  description = "[DEV ONLY] - Security group to allow deployer (myself) ssh into the cluster w. SSH from $MY_IPV4"
  type = object({
    name = string
    arn  = string
    id   = string
  })
  sensitive = true
}

