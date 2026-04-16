resource "aws_ecs_cluster" "this" {
  name = "${var.project}-${var.environment}"

  setting {
    name  = "containerInsights"
    value = var.container_insights ? "enabled" : "disabled"
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-ecs-cluster"
  })
}
