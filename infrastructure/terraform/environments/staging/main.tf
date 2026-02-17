terraform {
  # Backend específico para staging (opcional)
  # backend "s3" {
  #   bucket = "foodoffice-terraform-state-staging"
  #   key    = "staging/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

module "infrastructure" {
  source = "../../"

  environment = var.environment
  project_name = var.project_name
  region = var.region
}
