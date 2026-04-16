output "service_name" {
  description = "Name of the ECS worker service"
  value       = aws_ecs_service.this.name
}

output "task_definition_arn" {
  description = "ARN of the worker task definition"
  value       = aws_ecs_task_definition.this.arn
}
