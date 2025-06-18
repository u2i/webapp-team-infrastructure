# Dev environment configuration

# Include root configuration
include "root" {
  path = find_in_parent_folders()
}

# Include environment variables
include "env" {
  path = "./env.hcl"
}

# Use the U2I webapp-base module
terraform {
  source = "git::https://github.com/u2i/u2i-terraform-modules.git//modules/u2i-webapp-base?ref=main"
}

# Dev-specific inputs
inputs = {
  # Cloud Deploy and Artifact Registry enabled for dev
  enable_cloud_deploy      = true
  enable_artifact_registry = true
  
  # Disable binary authorization for dev
  enable_binary_authorization = false
  
  # Override any dev-specific values here
  # For example, you might want smaller resource sizes in dev
}