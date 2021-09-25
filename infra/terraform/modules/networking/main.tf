# Module contains the core networking resources for the tileserver application. This means 2 public 
# and private subnets in the same region, but different AZs, and the IGW, NATs, EIPs, 
# and route table associations for the private instances to access the internet.

provider "aws" {
  region  = "us-east-1"
  profile = "dmw2151"
}
