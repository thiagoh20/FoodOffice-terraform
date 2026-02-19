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

# Módulo de Security Groups para RDS y Lambda
module "rds_security_groups" {
  source = "git::https://github.com/thiagoh20/terraform-modules.git//security-groups?ref=main"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  admin_cidr_blocks = var.admin_cidr_blocks

  tags = merge(var.tags, {
    Name        = "foodoffice-rds-security-groups"
    Project     = "foodoffice"
    Environment = var.environment
    Owner       = "backend"
  })
}

# Módulo de RDS PostgreSQL
# Usando subredes privadas de datos para mayor seguridad
module "rds" {
  source = "git::https://github.com/thiagoh20/terraform-modules.git//rds?ref=main"

  project_name         = var.project_name
  environment          = var.environment
  rds_security_group_id = module.rds_security_groups.rds_security_group_id
  subnet_ids           = module.vpc.private_data_subnet_ids  # RDS en subredes privadas de datos

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  db_instance_class      = var.db_instance_class
  db_engine_version      = var.db_engine_version
  db_allocated_storage   = var.db_allocated_storage
  db_multi_az            = var.db_multi_az

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

# IAM Role para Lambda
resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-lambda-role"
    Project     = "foodoffice"
    Environment = var.environment
    Owner       = "backend"
  })
}

# IAM Policy para Lambda - Permisos VPC y CloudWatch
resource "aws_iam_role_policy" "lambda_vpc" {
  name = "${var.project_name}-${var.environment}-lambda-vpc-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ]
        Resource = "*"
      }
    ]
  })
}

# Archivo ZIP placeholder para Lambda
# Este archivo se crea temporalmente para inicializar Lambda
# El código real se despliega mediante SAM/CI-CD
data "archive_file" "lambda_placeholder" {
  type        = "zip"
  output_path = "/tmp/${var.project_name}-${var.environment}-lambda-placeholder.zip"
  source {
    content = <<-EOF
      exports.handler = async (event) => {
        return {
          statusCode: 200,
          body: JSON.stringify({ message: 'Lambda placeholder - actualizar con SAM' })
        };
      };
    EOF
    filename = "index.js"
  }
}

# Lambda Function en VPC
# Nota: El código de Lambda se despliega mediante SAM/CI-CD
# Este recurso define la configuración de infraestructura (VPC, IAM, etc.)
# El código se actualiza mediante despliegues separados de SAM
resource "aws_lambda_function" "main" {
  function_name = "${var.project_name}-${var.environment}-api"
  role          = aws_iam_role.lambda.arn
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout

  # Usar archivo ZIP placeholder o el proporcionado por el usuario
  filename         = var.lambda_zip_file != "" ? var.lambda_zip_file : data.archive_file.lambda_placeholder.output_path
  source_code_hash = var.lambda_zip_file != "" ? filebase64sha256(var.lambda_zip_file) : data.archive_file.lambda_placeholder.output_base64sha256

  # Configuración de VPC - Lambda en subredes privadas de aplicación
  vpc_config {
    subnet_ids         = module.vpc.private_app_subnet_ids
    security_group_ids = [module.rds_security_groups.lambda_security_group_id]
  }

  environment {
    variables = {
      DB_HOST     = module.rds.rds_endpoint
      DB_NAME     = var.db_name
      DB_USERNAME = var.db_username
      DB_PASSWORD = var.db_password
      NODE_ENV    = var.environment
    }
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-lambda"
    Project     = "foodoffice"
    Environment = var.environment
    Owner       = "backend"
  })

  depends_on = [
    aws_iam_role_policy.lambda_vpc,
    module.vpc,
    module.rds_security_groups
  ]
}

# API Gateway REST API
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-${var.environment}-api"
  protocol_type = "HTTP"
  description   = "API Gateway para FoodOffice ${var.environment}"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["*"]
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-api"
    Project     = "foodoffice"
    Environment = var.environment
    Owner       = "backend"
  })
}

# API Gateway Integration con Lambda
resource "aws_apigatewayv2_integration" "lambda" {
  api_id = aws_apigatewayv2_api.main.id

  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.main.invoke_arn
  integration_method = "POST"
}

# API Gateway Route - Catch-all para todas las rutas
resource "aws_apigatewayv2_route" "main" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = var.environment
  auto_deploy = true

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-api-stage"
    Project     = "foodoffice"
    Environment = var.environment
    Owner       = "backend"
  })
}

# Permiso para que API Gateway invoque Lambda
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
