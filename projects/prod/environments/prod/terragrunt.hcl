# Production environment configuration

# Include root configuration
include "root" {
  path = find_in_parent_folders()
}

# Use the webapp-infrastructure module
terraform {
  source = "git::https://github.com/u2i/u2i-terraform-modules.git//modules/webapp-infrastructure?ref=main"
}

# Production-specific inputs
inputs = {
  environment = "prod"
  
  
  # Features for production
  enable_monitoring = true
  enable_binary_authorization = true
  enable_backup = true
  
  # Production-specific DNS
  dns_subdomain = "webapp"  # Main domain for production
  
  # Cloud Deploy configuration
  enable_cloud_deploy = true
  enable_artifact_registry = true
  require_approval = true  # Require approval for deployments
  
  # Production security settings
  enable_private_nodes = true
  enable_network_policy = true
  
  # Override any production-specific values here
}