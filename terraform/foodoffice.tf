# foodoffice Frontend
module "foodoffice_frontend_bucket_name" {
  source      = "git::https://github.com/thiagoh20/terraform-modules.git//s3?ref=main"
  bucket_name = "foodoffice-frontend"

  tags = merge(var.tags, {
    Name        = "foodoffice-frontend"
    Project     = "foodoffice"
    Environment = var.environment
    Owner       = "frontend"
  })
}

module "foodoffice_frontend_cloudfront" {
  source = "git::https://github.com/thiagoh20/terraform-modules.git//cloudfront?ref=main"

  domain_name    = module.foodoffice_frontend_bucket_name.bucket_regional_domain_name
  bucket_id      = module.foodoffice_frontend_bucket_name.bucket_id
  environment    = var.environment
  certificate_arn = try(var.certificate_arn, "")

  tags = merge(var.tags, {
    Name        = "foodoffice-frontend"
    Project     = "foodoffice"
    Environment = var.environment
    Owner       = "frontend"
  })
}

resource "aws_s3_bucket_policy" "frontend_cloudfront" {
  bucket = module.foodoffice_frontend_bucket_name.bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${module.foodoffice_frontend_bucket_name.bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = module.foodoffice_frontend_cloudfront.distribution_arn
          }
        }
      }
    ]
  })
}

# Módulo IAM OIDC para GitHub Actions
module "iam_oidc" {
  count = var.oidc_provider_arn != "" ? 1 : 0
  
  source = "git::https://github.com/thiagoh20/terraform-modules.git//iam-oidc?ref=main"

  github_repository = var.github_repository
  oidc_provider_arn = var.oidc_provider_arn
  environment       = var.environment
  bucket_arn        = module.foodoffice_frontend_bucket_name.bucket_arn
  distribution_arn  = module.foodoffice_frontend_cloudfront.distribution_arn
  role_name         = "github-actions-${replace(var.github_repository, "/", "-")}-${var.environment}"

  tags = merge(var.tags, {
    Name        = "github-actions-role"
    Project     = "foodoffice"
    Environment = var.environment
    Owner       = "infrastructure"
  })
}

# Módulo de VPC - Arquitectura de 3 capas
module "vpc" {
  source = "git::https://github.com/thiagoh20/terraform-modules.git//vpc?ref=main"

  project_name = var.project_name
  environment  = var.environment

  vpc_cidr                = var.vpc_cidr
  public_subnet_cidrs     = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_data_subnet_cidrs = var.private_data_subnet_cidrs
  enable_nat_instance     = var.enable_nat_instance
  nat_instance_type       = var.nat_instance_type

  tags = merge(var.tags, {
    Name        = "foodoffice-vpc"
    Project     = "foodoffice"
    Environment = var.environment
    Owner       = "infrastructure"
  })
}

# Módulo de Security Groups para RDS
module "rds_security_groups" {
  source = "git::https://github.com/thiagoh20/terraform-modules.git//security-groups?ref=main"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  
  # CAMBIO: Tu IP pública IPv4 para acceso administrativo a RDS 
  # Obtener tu IP actual: curl -4 ifconfig.me 
  admin_cidr_blocks = ["38.252.93.102/32"]

  tags = merge(var.tags, {
    Name        = "foodoffice-rds-security-groups"
    Project     = "foodoffice"
    Environment = var.environment
    Owner       = "backend"
  })
}

# Módulo de RDS PostgreSQL
module "rds" {
  source = "git::https://github.com/thiagoh20/terraform-modules.git//rds?ref=main"

  project_name         = var.project_name
  environment          = var.environment
  rds_security_group_id = module.rds_security_groups.rds_security_group_id
  
  # CAMBIO: RDS ahora vive en las subredes con acceso a internet
  subnet_ids           = module.vpc.public_subnet_ids  

  # CAMBIO: Obligatorio para recibir una IP pública de AWS
  publicly_accessible  = true

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  db_instance_class      = var.db_instance_class
  db_engine_version      = var.db_engine_version
  db_allocated_storage   = var.db_allocated_storage
  db_multi_az            = var.db_multi_az
  
  db_storage_encrypted   = true

  db_backup_retention_period = var.db_backup_retention_period
  db_backup_window           = var.db_backup_window
  db_maintenance_window      = var.db_maintenance_window

  db_skip_final_snapshot = var.db_skip_final_snapshot
  db_deletion_protection = var.db_deletion_protection

  tags = merge(var.tags, {
    Name        = "foodoffice-rds"
    Project     = "foodoffice"
    Environment = var.environment
    Owner       = "backend"
  })
}