# Both the builder instance and the core postgis instance need to assume a role to perform administrative/auth tasks 
# this file defines the reader policies they use to fetch data from s3/ssm

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

# Policy allows for reading incidental reading of parameters from SSM
resource "aws_iam_policy" "ssm_reader" {

  name = "osm_param_reader"

  # [WARN] - This is NOT only secure parameters - for storing secure params use 
  # the secrets store!
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "VisualEditor0",
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

resource "aws_iam_policy" "osm_s3_reader" {

  name = "osm_s3_reader"
  policy = jsonencode({
    # Policy allows for reading incidental parameters for environFrom S3
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:Get*",
          "s3:List*"
        ],
        "Resource" : "arn:aws:s3:::${var.s3_params_bucket}"
      }
    ]
  })

}

resource "aws_iam_policy" "ecr_full" {

  name = "ecr_full"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "VisualEditor0",
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
        "Sid" : "VisualEditor1",
        "Effect" : "Allow",
        "Action" : "ecr:*",
        "Resource" : "arn:aws:ecr:*:${var.account_id}:repository/*"
      }
    ]
  })
}

# Create an IAM role for each of the builder, jump, and db instances 
# [NOTE] Not suitable for attachement to EC2, need to attach the `aws_iam_instance_profile` created 
# from this IAM role
# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
resource "aws_iam_role" "osm_build_profile" {
  name               = "osm_build_db_profile"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy.json
  managed_policy_arns = [
    aws_iam_policy.ssm_reader.arn,
    aws_iam_policy.osm_s3_reader.arn
  ]
}

resource "aws_iam_role" "osm_db_profile" {
  name               = "osm_db_profile"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy.json
  managed_policy_arns = [
    aws_iam_policy.ssm_reader.arn,
    aws_iam_policy.osm_s3_reader.arn
  ]
}

resource "aws_iam_role" "jump_profile" {
  name               = "jump_profile"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy.json
  managed_policy_arns = [
    aws_iam_policy.ssm_reader.arn,
    aws_iam_policy.osm_s3_reader.arn,
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
