terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.26.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.8.1"
    }
  }
  required_version = "~>1.13.4"

  backend "s3" {
    # Configuración del backend remoto para almacenar el estado
    # Los valores se pasan con -backend-config en los workflows
    # bucket         = "foodoffice-terraform-state"
    # key            = "environments/dev/terraform.tfstate"
    # region         = "us-east-2"
    # dynamodb_table = "terraform-state-lock"
    # encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}



