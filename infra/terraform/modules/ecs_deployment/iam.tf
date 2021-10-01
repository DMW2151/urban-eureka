resource "aws_iam_policy" "xray_all" {

  name = "xray_all"
  policy = jsonencode({
    # Policy allows for reading incidental parameters for environFrom S3
    Version = "2012-10-17"
    Statement = [
      {
        "Sid": "AllowAllXRay",
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

// TODO - Limit WHere possible...
resource "aws_iam_policy" "ecs_full" {

  name = "ecs"
  policy = jsonencode({
    # Policy allows for reading incidental parameters for environFrom S3
    Version = "2012-10-17"
    Statement = [
      {
        "Sid": "AllowAllECS",
        "Effect" : "Allow",
        "Action" : [
          "ecs:*",
        ],
        "Resource" : "*"
      }
    ]
  })

}


data "aws_iam_policy_document" "ecs_agent" {

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_agent" {
  name               = "ecs-agent"
  assume_role_policy = data.aws_iam_policy_document.ecs_agent.json
  managed_policy_arns = [
    aws_iam_policy.xray_all.arn,
    aws_iam_policy.ecs_full.arn,
  ]
}

resource "aws_iam_role_policy_attachment" "ecs_agent" {
  role       = aws_iam_role.ecs_agent.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_agent" {
  name = "ecs-agent"
  role = aws_iam_role.ecs_agent.name
}