# Uncomment the block below to use S3 backend for remote state.
# Ensure the S3 bucket and DynamoDB table exist before enabling.
#
# terraform {
#   backend "s3" {
#     bucket         = "csv-bulk-importer-terraform-state"
#     key            = "dev/terraform.tfstate"
#     region         = "ap-northeast-1"
#     dynamodb_table = "csv-bulk-importer-terraform-locks"
#     encrypt        = true
#   }
# }
