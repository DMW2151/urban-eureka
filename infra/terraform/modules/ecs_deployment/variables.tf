variable "core_vpc" {
  description = "..."
  type = object({
    id         = string
    arn        = string
    cidr_block = string
  })
}

variable "private_subnet" {
  description = "..."
  type = object({
    id                   = string
    arn                  = string
    availability_zone_id = string
    availability_zone    = string
  })
}

variable "public_subnet_1" {
  description = "..."
  type = object({
    id                   = string
    arn                  = string
    availability_zone_id = string
    availability_zone    = string
  })
}


variable "public_subnet_2" {
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


variable "postgres_host_internal_ip" {
  description = "..."
  type        = string
}

variable "redis_host_internal_ip" {
  description = "..."
  type        = string
}

variable "osm_pg__worker_pwd" {
  description = "..."
  type        = string
}


variable "default_region" {
  description = "..."
  type        = string
}

variable "image_tag" {
  description = "..."
  type        = string
}


variable "osm__update_server" {
  description = "..."
  type        = string
}

