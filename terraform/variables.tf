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

variable "oidc_provider_arn" {
  description = "ARN del proveedor OIDC de GitHub Actions en AWS IAM"
  type        = string
  default     = ""
}

# Variables para RDS
variable "db_name" {
  description = "Nombre de la base de datos"
  type        = string
  default     = "foodoffice"
}

variable "db_username" {
  description = "Usuario maestro de la base de datos"
  type        = string
  default     = "foodoffice"
}

variable "db_password" {
  description = "Contraseña maestra de la base de datos (sensible)"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "Clase de instancia RDS (db.t2.micro para AWS Free Tier)"
  type        = string
  default     = "db.t2.micro"
}

variable "db_engine_version" {
  description = "Versión del motor PostgreSQL"
  type        = string
  default     = "16.1"
}

variable "db_allocated_storage" {
  description = "Almacenamiento inicial asignado en GB (20 GB máximo para AWS Free Tier)"
  type        = number
  default     = 20
}

variable "db_multi_az" {
  description = "Habilitar despliegue Multi-AZ"
  type        = bool
  default     = false
}

variable "db_backup_retention_period" {
  description = "Período de retención de backups en días (1 día para AWS Free Tier)"
  type        = number
  default     = 1
}

variable "db_backup_window" {
  description = "Ventana de backup"
  type        = string
  default     = "03:00-04:00"
}

variable "db_maintenance_window" {
  description = "Ventana de mantenimiento"
  type        = string
  default     = "mon:04:00-mon:05:00"
}

variable "db_skip_final_snapshot" {
  description = "Omitir snapshot final al destruir (establecer en false en producción)"
  type        = bool
  default     = true
}

variable "db_deletion_protection" {
  description = "Habilitar protección contra eliminación"
  type        = bool
  default     = false
}

variable "admin_cidr_blocks" {
  description = "Bloques CIDR permitidos para acceso administrativo a RDS (opcional)"
  type        = list(string)
  default     = []
}
