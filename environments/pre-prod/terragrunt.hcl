# Pre-production environment configuration

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

# Pre-prod specific inputs
inputs = {
  # Pre-prod has same features as prod for testing
  enable_cloud_deploy      = true
  enable_artifact_registry = true
  
  # Pre-prod is used to test production migrations
  # with production data, so needs similar config
}