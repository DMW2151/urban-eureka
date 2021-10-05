# User data for the builder instance, the main postgis instance, and the jump server instance, see
# individual user data scripts referenced!

# Resource: https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file
data "template_file" "postgis-user-data" {
  template = file("./../modules/database_instances/user_data/build_std_postgis.sh")
}

data "template_file" "postgis-builder-user-data" {
  template = file("./../modules/database_instances/user_data/build_builder_postgis.sh")
}

# User data for jump server - adds some basic utilities to a plain AWS Linux EC2 instance
data "template_file" "jump-user-data" {
  template = file("./../modules/database_instances/user_data/build_jump_server.sh")
}
