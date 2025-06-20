# Dev environment configuration

# Include root configuration
include "root" {
  path = find_in_parent_folders()
}

# Use the webapp-infrastructure module
terraform {
  source = "git::https://github.com/u2i/u2i-terraform-modules.git//modules/webapp-infrastructure?ref=main"
}

# Dev-specific inputs
inputs = {
  environment = "dev"
  
  
  # Features for dev
  enable_monitoring = false
  enable_binary_authorization = false
  
  # Dev-specific DNS
  dns_subdomain = "dev.webapp"
  
  # Cloud Deploy configuration
  enable_cloud_deploy = true
  enable_artifact_registry = true
  
  # Override any dev-specific values here
}