# Parameters for the build process - create and use a standard parameter from the AWS parameter store
# [WARN]: These are not secure strings, for production consider using the AWS secrets store

# Resource: https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string
resource "random_string" "osm_pg__worker_pwd" {
  length  = 16
  special = true
}

# Password for OSM Builder/Worker instance
# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter
resource "aws_ssm_parameter" "osm_pg__worker_pwd" {
  name  = "osm_pg__worker_pwd"
  type  = "String"
  value = random_string.osm_pg__worker_pwd.result
}

# Export the IP of the OSM builder and database instances s.t. they can communicate w.o
# temporary entries to service discovery/cloud map
# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter
resource "aws_ssm_parameter" "osm_pg__builder_ip" {
  name  = "osm_pg__builder_ip"
  type  = "String"
  value = aws_spot_instance_request.builder-1.private_ip
}

# Export the IP of the OSM builder and database instances s.t. they can communicate w.o
# temporary entries to service discovery/cloud map
# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter
resource "aws_ssm_parameter" "osm_pg__db_ip" {
  name  = "osm_pg__db_ip"
  type  = "String"
  value = aws_instance.postgis-main-1.private_ip
}
