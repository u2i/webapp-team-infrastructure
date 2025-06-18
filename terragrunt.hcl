# Root terragrunt.hcl - Common configuration for all environments

locals {
  # Parse environment from path
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl", "env.hcl"))
  environment      = local.environment_vars.locals.environment
  
  # Determine project based on environment
  project_id = contains(["prod", "pre-prod"], local.environment) ? "u2i-tenant-webapp-prod" : "u2i-tenant-webapp"
  
  # Common tags for all resources
  common_tags = {
    managed_by     = "terragrunt"
    team           = "webapp-team"
    repository     = "webapp-team-infrastructure"
    compliance     = "iso27001-soc2-gdpr"
    data_residency = "eu"
    region         = "belgium"
    gdpr_compliant = "true"
  }
  
  # Backend bucket based on project
  backend_bucket = contains(["prod", "pre-prod"], local.environment) ? "u2i-tenant-webapp-prod-tfstate" : "u2i-tenant-webapp-tfstate"
}

# Configure Terraform
terraform {
  extra_arguments "common_vars" {
    commands = get_terraform_commands_that_need_vars()
    
    env_vars = {
      TF_VAR_project_id   = local.project_id
      TF_VAR_environment  = local.environment
      TF_VAR_common_tags  = jsonencode(local.common_tags)
    }
  }
  
  extra_arguments "auto_approve" {
    commands = ["apply"]
    arguments = ["-auto-approve"]
  }
}

# Remote state configuration
remote_state {
  backend = "gcs"
  
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  
  config = {
    bucket   = local.backend_bucket
    prefix   = "terraform/${local.environment}"
    project  = local.project_id
    location = "europe-west1"
    
    # Enable versioning for state history
    enable_bucket_policy_only = true
  }
}

# Generate common provider configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  
  contents = <<EOF
terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  user_project_override = true
  billing_project       = var.project_id
  project               = var.project_id
}

provider "google-beta" {
  user_project_override = true
  billing_project       = var.project_id
  project               = var.project_id
}
EOF
}

# Common inputs for all environments
inputs = {
  primary_region = "europe-west1"
  billing_account = "01AA86-A09BB4-30E84E"
  github_repo = "u2i/webapp-team-infrastructure"
}