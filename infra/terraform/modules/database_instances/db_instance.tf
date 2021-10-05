# EC2 Instance that hosts the core PostGIS database for dynamic tileserver.

# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance
resource "aws_instance" "postgis-main-1" {

  # Need an instance that can meet the minimum POSTGIS and h-store recommendations 
  # for a small/medium (100-1TB) geospatial database `m6g.large` is a graviton-backed
  # instance with the following specs.
  # 
  #   + 2 VCPU
  #   + 8 GB RAM
  #   + 120GB NVME ephemeral storage

  # Basic
  # AMI Name: ubuntu/images/hvm-ssd/ubuntu-focal-20.04-arm64-server-20210429
  ami           = "ami-00d1ab6b335f217cf"
  instance_type = "m6g.large"
  ebs_optimized = true

  # Security + Networking
  availability_zone           = var.db_subnet.availability_zone
  subnet_id                   = var.db_subnet.id
  associate_public_ip_address = false
  key_name                    = "public-jump-1"
  vpc_security_group_ids      = [var.vpc_all_traffic_sg.id, var.deployer_sg.id]

  # Storage
  # [TODO] This is meant to be a permanant DB, GP3 is better than NVME for longevity + security, 
  # check the performance effect of this datadir swap!
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 1000
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true

    tags = {
      Name   = "PostGIS Main - 1 - Root Volume"
      Module = "Database Instances"
    }

  }

  # User Data
  # See `build_std_postgis.sh` for details, builds a PostGIS database on start with 
  # specific settings for the build
  user_data            = data.template_file.postgis-user-data.template
  iam_instance_profile = aws_iam_instance_profile.osm_db_profile.name

  # Monitoring & Metadata Mgmt [These are default options added for clarity]
  monitoring = true
  metadata_options {
    http_endpoint = "enabled"
  }

  # Tags
  tags = {
    Name   = "PostGIS Main - 1"
    Module = "Database Instances"
  }

}
