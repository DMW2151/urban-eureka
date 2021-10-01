# Prepare for the event where we need to run multiple databases with replication behind a master node, create a DB
# service with multiple IPs 

resource "aws_service_discovery_private_dns_namespace" "local" {
  name        = "local"
  description = "...."
  vpc         = var.core_vpc.id
}

resource "aws_service_discovery_service" "db_svc" {
  name = "db_svc"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.local.id

    dns_records {
      ttl  = 300
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}


resource "aws_service_discovery_instance" "db_svc_master" {
  instance_id = "db_svc_master"
  service_id  = aws_service_discovery_service.db_svc.id

  attributes = {
    # AWS_EC2_INSTANCE_ID= aws_instance.postgis-main-1.id
    AWS_INSTANCE_IPV4 = aws_instance.postgis-main-1.private_ip
  }
}