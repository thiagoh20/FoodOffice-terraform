terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.26.0"
    }
  }
  required_version = "~>1.13.4"
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = var.tags
  }
}


# Módulo para S3 (se crea primero)
module "s3" {
  source = "./modules/s3"
  
  bucket_name = var.bucket_name
  tags        = var.tags
}

# Módulo para CloudFront (depende de S3)
module "cloudfront" {
  source = "./modules/cloudfront"
  
  bucket_domain_name = module.s3.bucket_domain_name
  bucket_id          = module.s3.bucket_id
  environment        = var.environment
  tags               = var.tags
}

# Actualizar la política de S3 con el ARN de CloudFront
resource "aws_s3_bucket_policy" "cloudfront_access_update" {
  bucket = module.s3.bucket_id

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
        Resource = "${module.s3.bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = module.cloudfront.distribution_arn
          }
        }
      }
    ]
  })

  depends_on = [module.cloudfront]
}

# Módulo para IAM con OIDC
module "iam_oidc" {
  source = "./modules/iam-oidc"
  
  github_repository = var.github_repository
  environment       = var.environment
  bucket_arn        = module.s3.bucket_arn
  distribution_arn  = module.cloudfront.distribution_arn
  tags              = var.tags
}


