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

# Outputs útiles para SAM (Lambda se gestiona en otro repositorio)
output "lambda_security_group_id" {
  description = "ID del Security Group para funciones Lambda (útil para SAM)"
  value       = module.rds_security_groups.lambda_security_group_id
}

output "lambda_subnet_ids" {
  description = "IDs de las subnets privadas de aplicación para Lambda (útil para SAM)"
  value       = module.vpc.private_app_subnet_ids
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

output "private_app_subnet_ids" {
  description = "IDs de las subnets privadas de aplicación (para Lambda, ECS, etc.)"
  value       = module.vpc.private_app_subnet_ids
}

output "private_data_subnet_ids" {
  description = "IDs de las subnets privadas de datos (para RDS, ElastiCache, etc.)"
  value       = module.vpc.private_data_subnet_ids
}

# Alias para compatibilidad
output "private_subnet_ids" {
  description = "IDs de las subnets privadas de datos (alias de private_data_subnet_ids)"
  value       = module.vpc.private_data_subnet_ids
}

output "subnet_ids" {
  description = "IDs de las subnets privadas de datos para RDS (alias de private_data_subnet_ids)"
  value       = module.vpc.private_data_subnet_ids
}

output "database_url" {
  description = "URL completa de conexión a la base de datos (sensible)"
  value       = module.rds.database_url
  sensitive   = true
}

# Outputs de Lambda - Comentados porque Lambda se gestiona con SAM en otro repositorio
# output "lambda_function_name" {
#   description = "Nombre de la función Lambda"
#   value       = aws_lambda_function.main.function_name
# }

# output "lambda_function_arn" {
#   description = "ARN de la función Lambda"
#   value       = aws_lambda_function.main.arn
# }

# output "lambda_function_invoke_arn" {
#   description = "ARN de invocación de la función Lambda"
#   value       = aws_lambda_function.main.invoke_arn
# }

# Outputs de API Gateway - Comentados porque API Gateway se gestiona con SAM en otro repositorio
# output "api_gateway_id" {
#   description = "ID del API Gateway"
#   value       = aws_apigatewayv2_api.main.id
# }

# output "api_gateway_endpoint" {
#   description = "URL del endpoint del API Gateway"
#   value       = aws_apigatewayv2_api.main.api_endpoint
# }

# output "api_gateway_execution_arn" {
#   description = "ARN de ejecución del API Gateway"
#   value       = aws_apigatewayv2_api.main.execution_arn
# }

# output "api_gateway_stage_invoke_url" {
#   description = "URL de invocación del stage del API Gateway"
#   value       = "${aws_apigatewayv2_api.main.api_endpoint}/${aws_apigatewayv2_stage.main.name}"
# }