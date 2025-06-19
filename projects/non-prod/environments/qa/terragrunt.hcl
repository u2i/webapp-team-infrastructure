# QA environment configuration

# Include root configuration
include "root" {
  path = find_in_parent_folders()
}

# Use the webapp-infrastructure module
terraform {
  source = "git::https://github.com/u2i/u2i-terraform-modules.git//modules/webapp-infrastructure?ref=main"
}

# QA-specific inputs
inputs = {
  environment = "qa"
  
  # Resource sizing for QA
  gke_node_count = 2
  gke_machine_type = "e2-standard-2"
  
  # Features for QA
  enable_monitoring = true
  enable_binary_authorization = false
  
  # QA-specific DNS
  dns_subdomain = "qa.webapp"
  
  # Cloud Deploy configuration
  enable_cloud_deploy = true
  enable_artifact_registry = true
  
  # Override any QA-specific values here
}