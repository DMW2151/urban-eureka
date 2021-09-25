# Default ECS Task Execution Role, includes permissions for ECS execution such as
#   - ecr:GetAuthorizationToken
#   - ecr:BatchCheckLayerAvailability
#   - ecr:GetDownloadUrlForLayer
#   - ecr:BatchGetImage
#   - logs:CreateLogStream
#   - logs:PutLogEvents

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html#create-task-execution-role
data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}