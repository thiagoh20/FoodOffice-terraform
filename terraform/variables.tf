variable "environment" {
  description = "Ambiente de despliegue (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "El ambiente debe ser: dev, staging o prod"
  }
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

variable "tags" {
  description = "Tags comunes para todos los recursos"
  type        = map(string)
  default = {
    Project     = "FoodOffice"
    ManagedBy   = "Terraform"
    Environment = ""
  }
}

variable "aws_region" {
  description = "Región de AWS donde se desplegará la infraestructura"
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

variable "certificate_arn" {
  description = "ARN del certificado SSL en ACM (debe estar en us-east-1). Opcional, si no se proporciona se usa el certificado por defecto de CloudFront"
  type        = string
  default     = ""
}

variable "base_domain" {
  description = "Dominio base para el sitio. Opcional, se usa solo si se necesita construir un dominio personalizado"
  type        = string
  default     = ""
}
