# terraform/modules/s3/variables.tf
variable "bucket_name" {
  description = "Nombre del bucket de S3"
  type        = string
}

variable "cloudfront_distribution_arn" {
  description = "ARN de la distribución de CloudFront (se actualizará después de crear CloudFront)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags para aplicar a los recursos"
  type        = map(string)
  default     = {}
}