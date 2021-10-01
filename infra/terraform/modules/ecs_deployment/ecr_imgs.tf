# Get the recent images and then assign them to their tasks...



# [NOTE]: Bit of a cheeky move to use local-exec, terraform isn't for this sort of thing 
resource "null_resource" "push-cache-img" {
  provisioner "local-exec" {
    command = "/bin/bash ../modules/ecs_deployment/localexec/build_and_push_img.sh ./../../../tile-cache tileserver-cache development linux/amd64"
  }

  depends_on = [
    aws_ecr_repository.tileserver-cache
  ]

  triggers = {
    src_hash = sha256(file("./../../../tile-cache/Dockerfile"))
  }
}


resource "null_resource" "push-nginx-img" {
  provisioner "local-exec" {
    command = "/bin/bash ../modules/ecs_deployment/localexec/build_and_push_img.sh ./../../../nginx nginx development linux/aarch64"
  }

  depends_on = [
    aws_ecr_repository.nginx
  ]

  triggers = {
    src_hash = sha256(file("./../../../nginx/nginx.conf"))
  }
}

resource "null_resource" "push-api-img" {
  provisioner "local-exec" {
    command = "/bin/bash ../modules/ecs_deployment/localexec/build_and_push_img.sh ./../../../tile-api/ tileserver-api development linux/amd64"
  }

  depends_on = [
    aws_ecr_repository.tileserver-api
  ]

  triggers = {
    src_hash = sha256(file("./../../../tile-api/cmd/tiles/main.go"))
  }

}

resource "null_resource" "push-xray-img" {
  provisioner "local-exec" {
    command = "/bin/bash ../modules/ecs_deployment/localexec/build_and_push_img.sh ./../../../xray-agent xray-agent development linux/amd64"
  }

  depends_on = [
    aws_ecr_repository.xray-agent
  ]

  triggers = {
    src_hash = sha256(file("./../../../xray-agent/Dockerfile"))
  }

}

# Find the latest version of the cache image
data "aws_ecr_image" "tileserver-cache-img" {
  repository_name = aws_ecr_repository.tileserver-cache.name
  image_tag       = "development"

  depends_on = [
    aws_ecr_repository.tileserver-cache,
    null_resource.push-cache-img
  ]
}

# Find the latest version of the API image and use the data
data "aws_ecr_image" "tileserver-api-img" {
  repository_name = aws_ecr_repository.tileserver-api.name
  image_tag       = "development"

  depends_on = [
    aws_ecr_repository.tileserver-api,
    null_resource.push-api-img
  ]
}

# Find the latest version of the cache image
data "aws_ecr_image" "xray-agent-img" {
  repository_name = aws_ecr_repository.xray-agent.name
  image_tag       = "development"

  depends_on = [
    aws_ecr_repository.xray-agent,
    null_resource.push-xray-img
  ]
}

data "aws_ecr_image" "nginx-img" {
  repository_name = aws_ecr_repository.nginx.name
  image_tag       = "development"

  depends_on = [
    aws_ecr_repository.nginx,
    null_resource.push-nginx-img
  ]
}