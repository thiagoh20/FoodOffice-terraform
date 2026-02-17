# terraform/modules/iam-oidc/outputs.tf
output "role_arn" {
  description = "ARN del rol de IAM para GitHub Actions"
  value       = aws_iam_role.github_actions.arn
}

output "role_name" {
  description = "Nombre del rol de IAM"
  value       = aws_iam_role.github_actions.name
}