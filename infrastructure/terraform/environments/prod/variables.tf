variable "environment" {
  description = "Ambiente de despliegue"
  type        = string
  default     = "prod"
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
