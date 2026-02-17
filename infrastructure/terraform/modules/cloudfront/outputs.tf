# terraform/modules/cloudfront/outputs.tf
output "distribution_id" {
  description = "ID de la distribución de CloudFront"
  value       = aws_cloudfront_distribution.frontend.id
}

output "distribution_arn" {
  description = "ARN de la distribución de CloudFront"
  value       = aws_cloudfront_distribution.frontend.arn
}

output "distribution_domain_name" {
  description = "Nombre de dominio de la distribución de CloudFront"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "distribution_url" {
  description = "URL completa de la distribución de CloudFront"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}
