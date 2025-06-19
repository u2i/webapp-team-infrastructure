# Staging environment configuration

# Include root configuration
include "root" {
  path = find_in_parent_folders()
}

# Use the webapp-infrastructure module
terraform {
  source = "git::https://github.com/u2i/u2i-terraform-modules.git//modules/webapp-infrastructure?ref=main"
}

# Staging-specific inputs
inputs = {
  environment = "staging"
  
  # Resource sizing for staging
  gke_node_count = 2
  gke_machine_type = "e2-standard-2"
  
  # Features for staging
  enable_monitoring = true
  enable_binary_authorization = false
  
  # Staging-specific DNS
  dns_subdomain = "staging.webapp"
  
  # Cloud Deploy configuration
  enable_cloud_deploy = true
  enable_artifact_registry = true
  
  # Override any staging-specific values here
}