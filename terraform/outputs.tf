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
  value       = try(module.iam_oidc[0].role_arn, null)
}

output "github_actions_role_name" {
  description = "Nombre del rol de IAM para GitHub Actions"
  value       = try(module.iam_oidc[0].role_name, null)
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

# Outputs de RDS
output "rds_endpoint" {
  description = "Endpoint de la instancia RDS"
  value       = module.rds.rds_endpoint
}

output "rds_address" {
  description = "Dirección (hostname) de la instancia RDS"
  value       = module.rds.rds_address
}

output "rds_port" {
  description = "Puerto de la instancia RDS"
  value       = module.rds.rds_port
}

output "rds_database_name" {
  description = "Nombre de la base de datos RDS"
  value       = module.rds.rds_database_name
}

output "rds_username" {
  description = "Usuario maestro de RDS"
  value       = module.rds.rds_username
  sensitive   = false
}

output "lambda_security_group_id" {
  description = "ID del Security Group para funciones Lambda"
  value       = module.rds_security_groups.lambda_security_group_id
}

output "rds_security_group_id" {
  description = "ID del Security Group para RDS"
  value       = module.rds_security_groups.rds_security_group_id
}

# Outputs de VPC
output "vpc_id" {
  description = "ID de la VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block de la VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs de las subnets públicas"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs de las subnets privadas (para RDS)"
  value       = module.vpc.private_subnet_ids
}

output "subnet_ids" {
  description = "IDs de las subnets privadas para Lambda/RDS (alias de private_subnet_ids)"
  value       = module.vpc.private_subnet_ids
}

output "database_url" {
  description = "URL completa de conexión a la base de datos (sensible)"
  value       = module.rds.database_url
  sensitive   = true
}