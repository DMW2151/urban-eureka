# Builder instance is requested from the spot market and has high memory + NVME ephemeral storage
# this instance is used to process the OSM import just once.
#
# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/spot_instance_request
# Also See: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance
resource "aws_spot_instance_request" "builder-1" {

  # [WARN] VPC spot instances DO NOT auto-terminate!
  #
  # Need an instance that can meet the minimum POSTGIS and h-store recommendations 
  # for a medium (100GB-1TB) geospatial database `m6gd.2xlarge` is a graviton-backed
  # instance with the following specs:
  # 
  #   + 8 VCPU
  #   + 32 GB RAM
  #   + 480GB NVME ephemeral storage
  #
  # I expect these jobs to be up for ~10 hrs, so a cost of ~ $1-2 is expected. **If** the scope of the job 
  # changes to include the entire world, bump to `m6gd.4xlarge`

  # Basic
  # AMI Name: ubuntu/images/hvm-ssd/ubuntu-focal-20.04-arm64-server-20210429
  ami           = "ami-00d1ab6b335f217cf"
  instance_type = "m6gd.2xlarge"

  # Spot Market Specific
  # Historically (Q3 2021 - These are hovering at about $0.15)
  # Leaving price at 0.00 so request expires immediatley, effectively bypassing `builder` stage
  spot_price           = "0.10"
  spot_type            = "one-time"
  valid_until          = timeadd(timestamp(), "1ms")
  wait_for_fulfillment = true

  # Security + Networking 
  # Launch into a private subnet in the same subnet as PostGIS Main - Data transferred between Amazon EC2, Amazon RDS, 
  # Amazon Redshift, Amazon ElastiCache instances, and Elastic Network Interfaces  in the same Availability Zone is 
  # free - Launch with the DB!
  availability_zone           = var.db_subnet.availability_zone
  subnet_id                   = var.db_subnet.id
  associate_public_ip_address = false
  key_name                    = "public-jump-1"
  vpc_security_group_ids      = [var.vpc_all_traffic_sg.id, var.deployer_sg.id]

  # Storage
  # Prefer XX6d family instances to XX6. Although we can crank up IOPs on GP3 instances, the NVME disk speeds OSM
  # builds by ~2x. Still request 100 GB of GP3 for osm.pbf files laying around during the build.
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 100
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true

    tags = {
      Name = "PostGIS Builder - 1"
    }

  }

  # User Data 
  # See `build_std_postgis.sh` for details, builds a PostGIS database on start with 
  # specific settings for the build
  user_data            = data.template_file.postgis-builder-user-data.template
  iam_instance_profile = aws_iam_instance_profile.osm_builder_profile.name

  # [WARN] These tags DO NOT propogate to the builder, expect builder to be named "-"
  # From AWS Docs: 
  #
  # The tags that you create for your Spot Instance requests only apply to the requests. These tags are not added automatically 
  # to the Spot Instance that the Spot service launches to fulfill the request. You must add tags to a Spot Instance yourself 
  # when you create the Spot Instance request or after the Spot Instance is launched.
  tags = {
    Name   = "PostGIS Builder"
    Module = "Database Instances"
  }

}