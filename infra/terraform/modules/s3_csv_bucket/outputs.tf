output "bucket_name" {
  description = "Name of the S3 CSV uploads bucket"
  value       = aws_s3_bucket.csv.id
}

output "bucket_arn" {
  description = "ARN of the S3 CSV uploads bucket"
  value       = aws_s3_bucket.csv.arn
}
