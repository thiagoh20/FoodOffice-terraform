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

