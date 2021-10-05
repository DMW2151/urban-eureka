# IAM roles for the OSM database build process.
#
# Both the builder instance and the core postgis instance need to assume a role to 
# perform administrative/auth tasks, this file defines the reader policies they use 
# to fetch data from s3/ssm. Also create a jump instance that can do a bit more admin
# and testing...

# Assume Role Policy - Default - Exists on AWS already
# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document
data "aws_iam_policy_document" "instance-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Policy allows for reading parameters from SSM
# [TODO]: Change to secrets mangager for "production" deployment
# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy
resource "aws_iam_policy" "ssm_reader" {

  name = "osm_param_reader"

  # [WARN] - This is NOT for secure parameters - use the secrets store!
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ssm:GetParametersByPath",
          "ssm:GetParameters",
          "ssm:GetParameter"
        ],
        "Resource" : "arn:aws:ssm:*:${var.account_id}:parameter/*"
      }
    ]
  })

}

# [DEV ONLY] Policy allows full access to ECR - Attached to the jump instance to allow testing and
# pushing sample images
# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy
resource "aws_iam_policy" "ecr_full" {

  name = "ecr_full"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ecr:GetRegistryPolicy",
          "ecr:DescribeRegistry",
          "ecr:GetAuthorizationToken",
          "ecr:DeleteRegistryPolicy",
          "ecr:PutRegistryPolicy",
          "ecr:PutReplicationConfiguration"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : "ecr:*",
        "Resource" : "arn:aws:ecr:*:${var.account_id}:repository/*"
      }
    ]
  })
}

# Create an IAM role for each of the builder, jump, and db instances
# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
resource "aws_iam_role" "osm_build_profile" {
  name               = "osm_build_db_profile"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy.json
  managed_policy_arns = [
    aws_iam_policy.ssm_reader.arn,
  ]
}

# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
resource "aws_iam_role" "osm_db_profile" {
  name               = "osm_db_profile"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy.json
  managed_policy_arns = [
    aws_iam_policy.ssm_reader.arn,
  ]
}

# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
resource "aws_iam_role" "jump_profile" {
  name               = "jump_profile"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy.json
  managed_policy_arns = [
    aws_iam_policy.ssm_reader.arn,
    aws_iam_policy.ecr_full.arn
  ]
}

# Create an aws_iam_instance_profile that can be attached to a new EC2 instance for each of the builder, 
# jump, and core-db instances
# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile
resource "aws_iam_instance_profile" "osm_build_profile" {
  name = "osm_build_instance_profile"
  role = aws_iam_role.osm_build_profile.name
}

# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile
resource "aws_iam_instance_profile" "osm_db_profile" {
  name = "osm_db_instance_profile"
  role = aws_iam_role.osm_db_profile.name
}

# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile
resource "aws_iam_instance_profile" "jump_profile" {
  name = "jump_instance_profile"
  role = aws_iam_role.jump_profile.name
}
