resource "aws_cloudwatch_log_group" "web" {
  name              = "/ecs/${var.project}/web"
  retention_in_days = var.retention_in_days

  tags = merge(var.tags, {
    Name    = "/ecs/${var.project}/web"
    Service = "web"
  })
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/${var.project}/worker"
  retention_in_days = var.retention_in_days

  tags = merge(var.tags, {
    Name    = "/ecs/${var.project}/worker"
    Service = "worker"
  })
}
