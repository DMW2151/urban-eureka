
# This isn't idiomatic of terraform...redeploy is tough...
resource "aws_security_group" "lambda_sg" {

  # General
  name                   = "lambda-sg"
  vpc_id                 = var.core_vpc.id
  description            = "..."
  revoke_rules_on_delete = true

  # Application Port - Within VPC - For app [TODO: rm]
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # Send to Anywhere...
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    name = "lb-sg"
  }

}


resource "aws_lambda_function" "updater_lambda" {
  architectures = ["arm64"]
  function_name = "osm_updater"
  memory_size   = 128
  package_type  = "Image"
  timeout       = 5
  role          = aws_iam_role.iam_for_lambda.arn
  image_uri     = "${data.aws_ecr_image.osm-updater-img.registry_id}.dkr.ecr.${var.default_region}.amazonaws.com/${data.aws_ecr_image.osm-updater-img.repository_name}:${var.image_tag}"
    publish = true
  vpc_config {
    subnet_ids = [
      var.private_subnet.id
    ]
    security_group_ids = [
      aws_security_group.lambda_sg.id
    ]
  }

  environment {
    variables = {
      PG__DATABASE       = "geospatial_core"
      PG__HOST           = "${var.postgres_host_internal_ip}" // Does not need svc discovery, leader node is static...
      PG__PORT           = "5432"
      PG__USER           = "osm_worker"
      OSM__UPDATE_SERVER = "${var.osm__update_server}"
    }
  }

  # ... other configuration ...
  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.update_logs,
  ]
}


resource "aws_iam_policy" "lambda_bind" {

  name = "lambda_bind"

  # [WARN] - This is NOT only secure parameters - for storing secure params use 
  # the secrets store!
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeNetworkInterfaces",
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeInstances",
        "ec2:AttachNetworkInterface"
      ],
      "Resource": "*"
    }
    ]
  })

}


resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  managed_policy_arns = [
    var.ssm_reader.arn,
  ]

}

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_role_policy_attachment" "lambda_bind" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_bind.arn
}

resource "aws_cloudwatch_log_group" "update_logs" {
  name              = "/aws/lambda/osm_updater"
  retention_in_days = 14
}