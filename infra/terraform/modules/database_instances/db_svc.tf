# The core PostGIS DB may need to distribute requests. In preparation for this event, where we need to 
# run multiple databases with replication behind a master node, create a DB service with multiple IPs,
# application may need to call any one of X nodes.

# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_private_dns_namespace
resource "aws_service_discovery_private_dns_namespace" "local" {
  name        = "local"
  description = "database service - includes main DB + all (any) read replicas"
  vpc         = var.core_vpc.id
}


# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_service
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


# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_instance
resource "aws_service_discovery_instance" "db_svc_master" {
  instance_id = "db_svc_master"
  service_id  = aws_service_discovery_service.db_svc.id

  attributes = {
    AWS_INSTANCE_IPV4 = aws_instance.postgis-main-1.private_ip
  }
}