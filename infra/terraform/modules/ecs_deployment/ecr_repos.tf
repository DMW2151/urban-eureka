# Create the ECR Repos for the Tileserver Tasks:
#   - Redis
#   - Tileserver application
#   - Xray Agent
#   - Nginx
#   - OSM Updater

# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository
resource "aws_ecr_repository" "osm-updater" {
  # Basic
  name                 = "osm-updater"
  image_tag_mutability = "MUTABLE"

  # Security constraints - Enable Snyk scan on push to repo
  image_scanning_configuration {
    scan_on_push = true
  }

  # Cannot be destroyed via terraform
  lifecycle {
    prevent_destroy = false
  }

}

# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository
resource "aws_ecr_repository" "tileserver-cache" {
  # Basic
  name                 = "tileserver-cache"
  image_tag_mutability = "MUTABLE"

  # Security constraints - Enable Snyk scan on push to repo
  image_scanning_configuration {
    scan_on_push = true
  }

  # Cannot be destroyed via terraform
  lifecycle {
    prevent_destroy = false
  }
}

# One for Nginx - Sits behind the Load Balancer and Gzips the response
# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository
resource "aws_ecr_repository" "nginx" {
  # Basic
  name                 = "nginx"
  image_tag_mutability = "MUTABLE"

  # Security constraints - Enable Snyk scan on push to repo
  image_scanning_configuration {
    scan_on_push = true
  }

  # Cannot be destroyed via terraform
  lifecycle {
    prevent_destroy = false
  }

}

# One Repository for the Application/API
# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository
resource "aws_ecr_repository" "tileserver-api" {
  # Basic
  name                 = "tileserver-api"
  image_tag_mutability = "MUTABLE"

  # Security constraints - Enable Snyk scan on push to repo
  image_scanning_configuration {
    scan_on_push = true
  }

  # Cannot be destroyed via terraform
  lifecycle {
    prevent_destroy = false
  }
}

# One Repository for the Xray Agent
# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository
resource "aws_ecr_repository" "xray-agent" {
  name                 = "xray-agent"
  image_tag_mutability = "MUTABLE"

  # Security constraints - Enable Snyk scan on push to repo
  image_scanning_configuration {
    scan_on_push = true
  }

  # Cannot be destroyed via terraform
  lifecycle {
    prevent_destroy = false
  }
}