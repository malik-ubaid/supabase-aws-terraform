output "bucket_id" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.main.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.main.arn
}

output "bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.main.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = aws_s3_bucket.main.bucket_regional_domain_name
}

output "bucket_hosted_zone_id" {
  description = "Route 53 Hosted Zone ID for the S3 bucket"
  value       = aws_s3_bucket.main.hosted_zone_id
}

output "bucket_region" {
  description = "AWS region where the bucket is located"
  value       = aws_s3_bucket.main.region
}

output "access_logs_bucket_id" {
  description = "Name of the S3 access logs bucket"
  value       = var.enable_access_logging ? aws_s3_bucket.access_logs[0].id : null
}

output "access_logs_bucket_arn" {
  description = "ARN of the S3 access logs bucket"
  value       = var.enable_access_logging ? aws_s3_bucket.access_logs[0].arn : null
}

output "kms_key_id" {
  description = "KMS key ID used for S3 encryption"
  value       = var.enable_server_side_encryption && var.kms_key_id == null ? aws_kms_key.s3[0].key_id : var.kms_key_id
}

output "kms_key_arn" {
  description = "KMS key ARN used for S3 encryption"
  value       = var.enable_server_side_encryption && var.kms_key_id == null ? aws_kms_key.s3[0].arn : var.kms_key_id
}