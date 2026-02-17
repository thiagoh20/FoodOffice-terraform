# terraform/modules/s3/main.tf
# Usamos data source para el bucket existente
# Si el bucket no existe, debe crearse manualmente o cambiar esto a resource
data "aws_s3_bucket" "frontend" {
  bucket = var.bucket_name
}

# Recursos de configuración del bucket (se aplican al bucket existente)
resource "aws_s3_bucket_versioning" "frontend" {
  bucket = data.aws_s3_bucket.frontend.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = data.aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = data.aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# La política del bucket se crea en el nivel raíz después de CloudFront
# para evitar dependencias circulares