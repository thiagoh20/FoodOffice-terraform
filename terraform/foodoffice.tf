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
