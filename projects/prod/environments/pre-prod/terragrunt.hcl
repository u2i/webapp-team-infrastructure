# Pre-prod environment configuration

# Include root configuration
include "root" {
  path = find_in_parent_folders()
}

# Use the webapp-infrastructure module
terraform {
  source = "git::https://github.com/u2i/u2i-terraform-modules.git//modules/webapp-infrastructure?ref=main"
}

# Pre-prod-specific inputs
inputs = {
  environment = "pre-prod"
  
  
  # Features for pre-prod
  enable_monitoring = true
  enable_binary_authorization = true
  
  # Pre-prod-specific DNS
  dns_subdomain = "pre-prod.webapp"
  
  # Cloud Deploy configuration
  enable_cloud_deploy = true
  enable_artifact_registry = true
  require_approval = true  # Require approval for deployments
  
  # Override any pre-prod-specific values here
}