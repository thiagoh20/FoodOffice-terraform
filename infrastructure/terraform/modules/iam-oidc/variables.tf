# terraform/modules/iam-oidc/variables.tf
variable "github_repository" {
  description = "Repositorio de GitHub en formato 'owner/repo'"
  type        = string
}

variable "bucket_arn" {
  description = "ARN del bucket de S3"
  type        = string
}

variable "distribution_arn" {
  description = "ARN de la distribución de CloudFront"
  type        = string
}

variable "tags" {
  description = "Tags para aplicar a los recursos"
  type        = map(string)
  default     = {}
}