variable "core_vpc" {
  description = "..."
  type = object({
    id         = string
    arn        = string
    cidr_block = string
  })
}

variable "s3_params_bucket" {
  description = "..."
  type        = string
}

variable "account_id" {
  description = "..."
  type        = string
}

variable "db_subnet" {
  description = "..."
  type = object({
    id                   = string
    arn                  = string
    availability_zone_id = string
    availability_zone    = string
  })
}

variable "jump_subnet" {
  description = "..."
  type = object({
    id                   = string
    arn                  = string
    availability_zone_id = string
    availability_zone    = string
  })
}

variable "vpc_all_traffic_sg" {
  description = "..."
  type = object({
    name = string
    arn  = string
    id   = string
  })
}

variable "deployer_sg" {
  description = "..."
  type = object({
    name = string
    arn  = string
    id   = string
  })
  sensitive = true
}

