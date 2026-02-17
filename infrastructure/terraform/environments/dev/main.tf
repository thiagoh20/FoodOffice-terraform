
module "infrastructure" {
  source = "../../"

  environment     = var.environment
  project_name    = var.project_name
  region          = var.region
  aws_region      = var.region
  bucket_name     = var.bucket_name
  github_repository = var.github_repository
  
  tags = {
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Environment = var.environment
  }
}
