terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.80, < 7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Il target (floci | aws) è il nome del workspace Terraform.
# Ogni workspace ha il suo state: impossibile "applicare su AWS" lo state di Floci.
locals {
  target   = terraform.workspace
  is_floci = local.target == "floci"
}

provider "aws" {
  region = var.region

  # --- AWS reale: credenziali dal profilo della AWS CLI ---
  profile = local.is_floci ? null : var.aws_profile

  # --- Floci: credenziali fittizie e niente controlli verso AWS ---
  access_key                  = local.is_floci ? "test" : null
  secret_key                  = local.is_floci ? "test" : null
  skip_credentials_validation = local.is_floci
  skip_metadata_api_check     = local.is_floci
  skip_requesting_account_id  = local.is_floci
  s3_use_path_style           = local.is_floci

  dynamic "endpoints" {
    for_each = local.is_floci ? [var.floci_endpoint] : []
    content {
      ec2     = endpoints.value
      rds     = endpoints.value
      s3      = endpoints.value
      iam     = endpoints.value
      sts     = endpoints.value
      ssm     = endpoints.value
      budgets = endpoints.value
    }
  }

  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      Target    = local.target
    }
  }
}

# Blocca l'uso dal workspace "default": serve scegliere esplicitamente floci o aws.
resource "terraform_data" "workspace_guard" {
  lifecycle {
    precondition {
      condition     = contains(["floci", "aws"], local.target)
      error_message = "Seleziona un workspace: 'terraform workspace select -or-create floci' oppure '... aws'."
    }
  }
}
