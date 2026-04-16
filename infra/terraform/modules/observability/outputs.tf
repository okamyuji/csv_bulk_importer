output "log_group_web_name" {
  description = "Name of the CloudWatch log group for the web service"
  value       = aws_cloudwatch_log_group.web.name
}

output "log_group_worker_name" {
  description = "Name of the CloudWatch log group for the worker service"
  value       = aws_cloudwatch_log_group.worker.name
}

output "log_group_web_arn" {
  description = "ARN of the CloudWatch log group for the web service"
  value       = aws_cloudwatch_log_group.web.arn
}

output "log_group_worker_arn" {
  description = "ARN of the CloudWatch log group for the worker service"
  value       = aws_cloudwatch_log_group.worker.arn
}
