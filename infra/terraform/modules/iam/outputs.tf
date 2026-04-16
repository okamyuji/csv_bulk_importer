output "task_role_arn" {
  description = "ARN of the ECS task role (application permissions)"
  value       = aws_iam_role.ecs_task.arn
}

output "execution_role_arn" {
  description = "ARN of the ECS execution role (infrastructure permissions)"
  value       = aws_iam_role.ecs_execution.arn
}

output "task_role_name" {
  description = "Name of the ECS task role"
  value       = aws_iam_role.ecs_task.name
}

output "execution_role_name" {
  description = "Name of the ECS execution role"
  value       = aws_iam_role.ecs_execution.name
}
