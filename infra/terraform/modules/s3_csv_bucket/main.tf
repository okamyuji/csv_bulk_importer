resource "aws_s3_bucket" "csv" {
  bucket        = "${var.project}-${var.environment}-csv-uploads"
  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-csv-uploads"
  })
}

resource "aws_s3_bucket_versioning" "csv" {
  bucket = aws_s3_bucket.csv.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "csv" {
  bucket = aws_s3_bucket.csv.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "csv" {
  bucket = aws_s3_bucket.csv.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "csv" {
  bucket = aws_s3_bucket.csv.id

  rule {
    id     = "expire-csv-imports"
    status = "Enabled"

    filter {
      prefix = "csv_imports/"
    }

    expiration {
      days = var.csv_imports_expiration_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.csv_imports_expiration_days
    }
  }

  rule {
    id     = "expire-originals"
    status = "Enabled"

    filter {
      prefix = "originals/"
    }

    expiration {
      days = var.originals_expiration_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.originals_expiration_days
    }
  }
}
