# Roles for the ECS core Service (E.G Task )

# Default ECS Task Execution Role, includes permissions for ECS execution such as
#   - ecr:GetAuthorizationToken
#   - ecr:BatchCheckLayerAvailability
#   - ecr:GetDownloadUrlForLayer
#   - ecr:BatchGetImage
#   - logs:CreateLogStream
#   - logs:PutLogEvents
#
# Don't need to add XRAY or the like to the execution role, but need to make sure that 
# the ECS machine has X-RAY!
#
# Does need cloud map though! [TODO]: Define this as a resource rather than the modified `ecsTaskExecutionRole`
#
# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
# Resource Note: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html#create-task-execution-role
data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}

# Create an ECS agent role that has a (too) wide set of permissions - allows all permissions 
# in XRAY (needed) and ECS (*NOT* NEEDED [TODO] Limit!) + all permissions from AmazonEC2ContainerServiceforEC2Role
# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
resource "aws_iam_role" "ecs_agent" {
  name               = "ecs-agent"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  managed_policy_arns = [
    aws_iam_policy.xray_all.arn,
    aws_iam_policy.ecs_full.arn,
  ]
}

# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy
resource "aws_iam_policy" "xray_all" {

  name = "xray_all"

  policy = jsonencode({
    # Policy allows for reading incidental parameters for environFrom S3
    Version = "2012-10-17"
    Statement = [
      {
        "Sid" : "AllowAllXRay",
        "Effect" : "Allow",
        "Action" : [
          "xray:*",
        ],
        "Resource" : [
          "*"
        ]
      }
    ]
  })

}


# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy
resource "aws_iam_policy" "ecs_full" {

  name = "ecs"
  policy = jsonencode({
    # Policy allows for reading incidental parameters for environFrom S3
    Version = "2012-10-17"
    Statement = [
      {
        "Sid" : "AllowAllECS",
        "Effect" : "Allow",
        "Action" : [
          "ecs:*",
        ],
        "Resource" : "*"
      }
    ]
  })

}

# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document
data "aws_iam_policy_document" "ec2_assume_role" {

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
resource "aws_iam_role_policy_attachment" "ecs_agent" {
  role       = aws_iam_role.ecs_agent.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# Resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_instance_profile
resource "aws_iam_instance_profile" "ecs_agent" {
  name = "ecs-agent"
  role = aws_iam_role.ecs_agent.name
}