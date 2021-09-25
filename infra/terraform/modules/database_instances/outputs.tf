# Values to export to other (ECS) module, 

# Internal IP address for the core PostGIS DB
output "postgres_host_internal_ip" {
  value = aws_instance.postgis-main-1.private_ip
}

# [WARN] Very Bad from a security perspective because the value of the "secret" is saved in the state 
# file, but since this isn't encrypted and passed as an env. var to ECS, just accept it. In production this
# would need radical improvement
output "osm_pg__worker_pwd" {
  value = aws_ssm_parameter.osm_pg__worker_pwd.value
}