# QA environment configuration

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

# QA-specific inputs
inputs = {
  # QA might not need Cloud Deploy if deployments are manual
  enable_cloud_deploy      = false
  enable_artifact_registry = true
  
  # QA-specific configurations
  # like test data buckets, synthetic monitoring, etc.
}