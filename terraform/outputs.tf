output "environment" {
  description = "Ambiente actual"
  value       = var.environment
}

output "project_name" {
  description = "Nombre del proyecto"
  value       = var.project_name
}

output "github_actions_role_arn" {
  description = "ARN del rol de IAM para GitHub Actions (OIDC)"
  value       = module.iam_oidc.role_arn
}

output "github_actions_role_name" {
  description = "Nombre del rol de IAM para GitHub Actions"
  value       = module.iam_oidc.role_name
}

output "cloudfront_distribution_id" {
  description = "ID de la distribución de CloudFront"
  value       = module.foodoffice_frontend_cloudfront.distribution_id
}

output "cloudfront_distribution_url" {
  description = "URL completa de la distribución de CloudFront"
  value       = module.foodoffice_frontend_cloudfront.distribution_url
}

output "cloudfront_distribution_arn" {
  description = "ARN de la distribución de CloudFront"
  value       = module.foodoffice_frontend_cloudfront.distribution_arn
}

output "s3_bucket_name" {
  description = "Nombre del bucket S3"
  value       = module.foodoffice_frontend_bucket_name.bucket_id
}

output "s3_bucket_arn" {
  description = "ARN del bucket S3"
  value       = module.foodoffice_frontend_bucket_name.bucket_arn
}