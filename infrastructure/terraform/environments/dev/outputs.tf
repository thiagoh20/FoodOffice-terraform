output "environment" {
  description = "Ambiente de despliegue"
  value       = module.infrastructure.environment
}

output "github_actions_role_arn" {
  description = "ARN del rol de IAM para GitHub Actions (OIDC)"
  value       = module.infrastructure.github_actions_role_arn
}
