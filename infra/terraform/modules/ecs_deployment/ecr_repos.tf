# Create the ECR Repos for the Tileserver Tasks, one for Redis
# one for the tileserver application itself...

# One Repository for the Cache/Sidecar
resource "aws_ecr_repository" "tileserver-cache" {
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

# One Repository for the Application/API
resource "aws_ecr_repository" "tileserver-api" {
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

