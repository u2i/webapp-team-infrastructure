# Root terragrunt.hcl - Common configuration for all environments

locals {
  # Parse project from path
  path_parts = split("/", path_relative_to_include())
  
  # Determine project from path: projects/{project}/terragrunt.hcl
  project_context = length(local.path_parts) >= 2 ? local.path_parts[1] : ""
  
  # Map project context to actual GCP project ID
  project_id = local.project_context == "prod" ? "u2i-tenant-webapp-prod" : "u2i-tenant-webapp"
  
  # Determine domain based on project
  domain = local.project_context == "prod" ? "u2i.com" : "u2i.dev"
  
  # Common tags for all resources
  common_tags = {
    managed_by     = "terragrunt"
    team           = "webapp-team"
    repository     = "webapp-team-infrastructure"
    compliance     = "iso27001-soc2-gdpr"
    data_residency = "eu"
    project        = local.project_context
  }
  
  # Backend bucket based on project
  backend_bucket = local.project_context == "prod" ? "u2i-tenant-webapp-prod-tfstate" : "u2i-tenant-webapp-tfstate"
  
  # State key is always "project" for project-level configs
  state_key = "project"
}

# Configure Terraform
terraform {
  extra_arguments "common_vars" {
    commands = get_terraform_commands_that_need_vars()
    
    env_vars = {
      TF_VAR_project_id   = local.project_id
      TF_VAR_environment  = local.project_context
      TF_VAR_domain       = local.domain
      TF_VAR_common_tags  = jsonencode(local.common_tags)
    }
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
    prefix   = "terragrunt/${local.state_key}"
    project  = local.project_id
    location = "europe-west1"
    
    # Enable versioning for state history
    enable_bucket_policy_only = true
  }
}

# Generate common provider configuration
generate "provider" {
  path      = "providers.tf"
  if_exists = "overwrite"
  
  contents = <<EOF
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
  primary_region  = "europe-west1"
  billing_account = "017E25-21F01C-DF5C27"
  github_org      = "u2i"
  github_repo     = "webapp-team-infrastructure"
}