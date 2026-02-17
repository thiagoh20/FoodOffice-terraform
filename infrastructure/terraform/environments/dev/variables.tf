variable "environment" {
  description = "Ambiente de despliegue"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "foodoffice"
}

variable "region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Nombre del bucket de S3 (debe ser único globalmente)"
  type        = string
}

variable "github_repository" {
  description = "Repositorio de GitHub en formato 'owner/repo' (ej: 'usuario/foodoffice')"
  type        = string
}
