# terraform/terraform.tfvars.example
aws_region        = "us-east-1"
bucket_name       = "foodoffice-frontend"
github_repository = "tu-usuario/FoodOffice"
environment = "dev"

tags = {
  Project     = "FoodOffice"
  Environment = "dev"
  ManagedBy   = "Terraform"
}