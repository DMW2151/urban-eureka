terraform {

  backend "s3" {
    bucket = "dmw2151-osm"
    key    = "state_files/tileserver-stack.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.61.0"
    }
  }

  required_version = ">= 1.0.3"

}

# Providers
provider "aws" {
  region  = "us-east-1"
  profile = "dmw2151"
}

# AWS account id of the active account
data "aws_caller_identity" "current" {}

# [DEV ONLY] IP address of the terraform user - assumes deployment from local env.
data "http" "deployerip" {
  url = "http://ipv4.icanhazip.com"
}

# Modules
module "networking" {
  source      = "../modules/networking"
  deployer_ip = "${chomp(data.http.deployerip.body)}/32"
}

module "ecs" {
  source                    = "../modules/ecs_deployment"
  default_region            = "us-east-1"
  core_vpc                  = module.networking.core-vpc
  private_subnet            = module.networking.subn-us-east-1f-private
  public_subnet_1           = module.networking.subn-us-east-1f-public
  public_subnet_2           = module.networking.subn-us-east-1d-public
  redis_host_internal_ip    = "tilecache"
  postgres_host_internal_ip = module.database_instances.postgres_host_internal_ip
  vpc_all_traffic_sg        = module.networking.vpc-all-traffic-sg
  image_tag                 = "development"
  osm_pg__worker_pwd        = module.database_instances.osm_pg__worker_pwd
  osm__update_server        = "http://download.geofabrik.de/north-america/us/delaware-updates"
  ssm_reader                = module.database_instances.osm_ssm_reader_policy
}


# Module used to instantiate the database instances - this includes the following:
#  1. A Jump Server Instance - a xxx.nano/xxx.micro instance in the private subnet used for administration
#  2. A Database Builder Instance  - a xxx.2xl - xxx.8xl instance purchased on the spot market 
#     used for building the OSM DB
#  3. A core DB Instance - a xxx.large instance for serving the geospatial database; tbd, depending on the
#     instance type, maay bump to xxxx.xlarge 
module "database_instances" {
  source             = "../modules/database_instances"
  account_id         = data.aws_caller_identity.current.account_id
  core_vpc           = module.networking.core-vpc
  db_subnet          = module.networking.subn-us-east-1f-private
  jump_subnet        = module.networking.subn-us-east-1f-public
  vpc_all_traffic_sg = module.networking.vpc-all-traffic-sg
  deployer_sg        = module.networking.deployer-ssh-to-vpc-sg
}

