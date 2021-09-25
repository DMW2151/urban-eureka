# Find the latest version of the cache image
data "aws_ecr_image" "tileserver-cache-img" {
  repository_name = aws_ecr_repository.tileserver-cache.name
  image_tag       = "development"

  depends_on = [
    aws_ecr_repository.tileserver-cache
  ]
}

# Find the latest version of the API image and use the data
data "aws_ecr_image" "tileserver-api-img" {
  repository_name = aws_ecr_repository.tileserver-api.name
  image_tag       = "development"

  depends_on = [
    aws_ecr_repository.tileserver-api
  ]
}