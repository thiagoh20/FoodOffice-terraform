# terraform/modules/cloudfront/variables.tf
variable "bucket_domain_name" {
  description = "Nombre de dominio del bucket de S3"
  type        = string
}

variable "bucket_id" {
  description = "ID del bucket de S3"
  type        = string
}

variable "tags" {
  description = "Tags para aplicar a los recursos"
  type        = map(string)
  default     = {}
}