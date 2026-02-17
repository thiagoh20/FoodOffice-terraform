# terraform/modules/s3/outputs.tf
output "bucket_id" {
  description = "ID del bucket de S3"
  value       = data.aws_s3_bucket.frontend.id
}

output "bucket_arn" {
  description = "ARN del bucket de S3"
  value       = data.aws_s3_bucket.frontend.arn
}

output "bucket_name" {
  description = "Nombre del bucket de S3"
  value       = data.aws_s3_bucket.frontend.id
}

output "bucket_domain_name" {
  description = "Nombre de dominio del bucket de S3"
  value       = data.aws_s3_bucket.frontend.bucket_domain_name
}