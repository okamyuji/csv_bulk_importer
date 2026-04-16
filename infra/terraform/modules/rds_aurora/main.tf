################################################################################
# DB Subnet Group
################################################################################

resource "aws_db_subnet_group" "this" {
  name       = "${var.project}-${var.environment}-aurora"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-aurora-subnet-group"
  })
}

################################################################################
# Cluster Parameter Group (utf8mb4)
################################################################################

resource "aws_rds_cluster_parameter_group" "this" {
  name        = "${var.project}-${var.environment}-aurora-cluster-params"
  family      = "aurora-mysql8.0"
  description = "Cluster parameter group for ${var.project} ${var.environment} with utf8mb4"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_connection"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_database"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_results"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "collation_connection"
    value = "utf8mb4_unicode_ci"
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-aurora-cluster-params"
  })
}

################################################################################
# DB Parameter Group
################################################################################

resource "aws_db_parameter_group" "this" {
  name        = "${var.project}-${var.environment}-aurora-db-params"
  family      = "aurora-mysql8.0"
  description = "DB parameter group for ${var.project} ${var.environment}"

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-aurora-db-params"
  })
}

################################################################################
# Aurora Cluster
################################################################################

resource "aws_rds_cluster" "this" {
  cluster_identifier = "${var.project}-${var.environment}-aurora"
  engine             = "aurora-mysql"
  engine_version     = var.engine_version
  database_name      = var.database_name
  master_username    = var.master_username

  manage_master_user_password = true

  db_subnet_group_name            = aws_db_subnet_group.this.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name
  vpc_security_group_ids          = [var.sg_id]

  storage_encrypted       = var.storage_encrypted
  backup_retention_period = var.backup_retention_period
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = var.skip_final_snapshot

  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.project}-${var.environment}-aurora-final-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-aurora-cluster"
  })

  lifecycle {
    ignore_changes = [final_snapshot_identifier]
  }
}

################################################################################
# Aurora Instances
################################################################################

resource "aws_rds_cluster_instance" "this" {
  count = var.instance_count

  identifier         = "${var.project}-${var.environment}-aurora-${count.index}"
  cluster_identifier = aws_rds_cluster.this.id
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version
  instance_class     = var.instance_class

  db_parameter_group_name = aws_db_parameter_group.this.name
  db_subnet_group_name    = aws_db_subnet_group.this.name

  publicly_accessible = false

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-aurora-instance-${count.index}"
    Role = count.index == 0 ? "writer" : "reader"
  })
}
