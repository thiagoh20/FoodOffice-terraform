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
}

provider "aws" {
  region = var.aws_region
}



