terraform {
  # Backend específico para dev (opcional)
  # backend "s3" {
  #   bucket = "foodoffice-terraform-state-dev"
  #   key    = "dev/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

module "infrastructure" {
  source = "../../"

  environment = var.environment
  project_name = var.project_name
  region = var.region
}
