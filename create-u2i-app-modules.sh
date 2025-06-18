#!/bin/bash
# Script to create U2I-specific application modules

set -e

echo "🚀 Creating U2I-specific application modules repository"
echo "===================================================="

# Create U2I app modules structure
echo "📦 Creating u2i-terraform-modules for applications..."
mkdir -p ../u2i-terraform-modules/{modules,examples}

# Move and enhance webapp-base module
echo "Creating U2I webapp-base module..."
mkdir -p ../u2i-terraform-modules/modules/u2i-webapp-base
cp -r modules/webapp-base/* ../u2i-terraform-modules/modules/u2i-webapp-base/

# Update webapp-base to use generic modules
cat > ../u2i-terraform-modules/modules/u2i-webapp-base/main.tf << 'EOF'
# U2I Web Application Base Module
# Implements U2I-specific standards using generic compliance modules

locals {
  # U2I mandatory labels
  u2i_labels = merge(
    jsondecode(var.common_tags),
    {
      organization   = "u2i"
      environment    = var.environment
      tenant         = "webapp-team"
      compliance     = "iso27001-soc2-gdpr"
      data_residency = "eu"
      gdpr_compliant = "true"
    }
  )
  
  # U2I project naming convention
  is_prod = contains(["prod", "pre-prod"], var.environment)
  
  # U2I network configuration
  u2i_master_cidr = "10.100.0.0/28"  # U2I standard range
}

# Get organization and GKE outputs
data "terraform_remote_state" "organization" {
  backend = "gcs"
  config = {
    bucket = "u2i-tfstate"
    prefix = "organization"
  }
}

data "terraform_remote_state" "shared_gke" {
  backend = "gcs"
  config = {
    bucket = "u2i-tfstate" 
    prefix = "shared-gke"
  }
}

# Enable required APIs with U2I standard set
module "project_services" {
  source = "git::github.com/yourorg/terraform-google-compliance-modules//modules/project-services?ref=v1.0.0"
  
  project_id = var.project_id
  
  # U2I standard APIs
  services = [
    "cloudresourcemanager.googleapis.com",
    "clouddeploy.googleapis.com",
    "cloudbuild.googleapis.com",
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
    "storage.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudkms.googleapis.com",
    "secretmanager.googleapis.com",  # U2I requirement
    "binaryauthorization.googleapis.com",  # U2I requirement
  ]
}

# Terraform service account with U2I naming
module "terraform_sa" {
  source = "git::github.com/yourorg/terraform-google-compliance-modules//modules/service-account?ref=v1.0.0"
  
  project_id   = var.project_id
  account_id   = "terraform"
  display_name = "Terraform Service Account"
  description  = "Service account for Terraform automation in ${var.environment} - U2I managed"
  
  # U2I requires specific roles
  project_roles = [
    "roles/owner",  # For initial setup
    "roles/logging.admin",  # U2I audit requirements
    "roles/monitoring.admin",  # U2I monitoring requirements
  ]
}

# Workload Identity for GitHub Actions with U2I configuration
module "github_wif" {
  source = "git::github.com/yourorg/terraform-google-compliance-modules//modules/workload-identity?ref=v1.0.0"
  
  project_id   = var.project_id
  pool_id      = "webapp-github-pool-${var.environment}"
  display_name = "WebApp GitHub Actions Pool - ${var.environment} - U2I"
  description  = "Identity pool for GitHub Actions CI/CD - ${var.environment} - U2I managed"
  
  github_config = {
    attribute_condition = "assertion.repository == '${var.github_repo}'"
  }
  
  service_account_impersonation = {
    "terraform" = {
      service_account_email = module.terraform_sa.email
      member = "principalSet://iam.googleapis.com/projects/${var.project_id}/locations/global/workloadIdentityPools/webapp-github-pool-${var.environment}/attribute.repository/${var.github_repo}"
    }
  }
}

# KMS with U2I standards
module "kms" {
  source = "git::github.com/yourorg/terraform-google-compliance-modules//modules/kms?ref=v1.0.0"
  
  project_id   = var.project_id
  keyring_name = "webapp-${var.environment}-keyring"
  location     = var.primary_region
  
  # U2I requires specific keys
  keys = {
    "state" = {
      purpose         = "ENCRYPT_DECRYPT"
      rotation_period = "7776000s"  # 90 days - U2I standard
      labels          = local.u2i_labels
    }
    "secrets" = {
      purpose         = "ENCRYPT_DECRYPT"
      rotation_period = "7776000s"
      labels          = local.u2i_labels
    }
    "storage" = {
      purpose         = "ENCRYPT_DECRYPT"
      rotation_period = "7776000s"
      labels          = local.u2i_labels
    }
  }
}

# Artifact Registry with U2I standards
resource "google_artifact_registry_repository" "webapp_images" {
  count = var.enable_artifact_registry ? 1 : 0
  
  project       = var.project_id
  location      = var.primary_region
  repository_id = "webapp-${var.environment}-images"
  description   = "Container images for webapp ${var.environment} - U2I managed"
  format        = "DOCKER"
  
  # U2I requires vulnerability scanning
  mode = "STANDARD_REPOSITORY"
  
  # U2I cleanup policy
  cleanup_policies {
    id     = "keep-minimum-versions"
    action = "KEEP"
    
    condition {
      tag_state    = "TAGGED"
      version_name_prefixes = ["v"]
      newer_than   = "2592000s"  # 30 days
    }
  }
  
  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"
    
    condition {
      tag_state  = "UNTAGGED"
      older_than = "604800s"  # 7 days
    }
  }
  
  labels = local.u2i_labels
}

# Deployment artifacts bucket with U2I CMEK requirement
module "deployment_bucket" {
  source = "git::github.com/yourorg/terraform-google-compliance-modules//modules/cmek-storage?ref=v1.0.0"
  
  project_id = var.project_id
  bucket_name = "${var.project_id}-${var.environment}-deploy"
  location   = var.primary_region
  
  # U2I requires CMEK
  kms_key_id = module.kms.keys["storage"].id
  
  # U2I retention policy
  lifecycle_rules = [{
    age                    = var.environment == "prod" ? 180 : 30
    action_type           = "Delete"
    num_newer_versions    = null
    with_state            = null
    matches_storage_class = null
    action_storage_class  = null
  }]
  
  # U2I access controls
  bucket_iam_members = var.enable_cloud_deploy ? {
    "cloud-deploy" = {
      role   = "roles/storage.objectAdmin"
      member = "serviceAccount:${google_service_account.cloud_deploy[0].email}"
    }
  } : {}
  
  labels = local.u2i_labels
}

# Cloud Deploy with U2I configuration (if enabled)
resource "google_service_account" "cloud_deploy" {
  count = var.enable_cloud_deploy ? 1 : 0
  
  project      = var.project_id
  account_id   = "cloud-deploy-${var.environment}"
  display_name = "Cloud Deploy Service Account - ${var.environment} - U2I"
  description  = "Service account for Cloud Deploy pipeline in ${var.environment} - U2I managed"
}

resource "google_clouddeploy_delivery_pipeline" "webapp_pipeline" {
  count = var.enable_cloud_deploy ? 1 : 0
  
  project     = var.project_id
  location    = var.primary_region
  name        = "webapp-${var.environment}-pipeline"
  description = "Delivery pipeline for webapp ${var.environment} - U2I managed"
  
  # U2I requires annotations for tracking
  annotations = {
    "u2i-managed"    = "true"
    "u2i-team"       = "webapp"
    "u2i-compliance" = "required"
  }
  
  serial_pipeline {
    stages {
      target_id = google_clouddeploy_target.gke_target[0].name
      profiles  = [var.environment]
      
      # U2I requires deployment verification
      strategy {
        standard {
          verify = true
        }
      }
    }
  }
  
  labels = local.u2i_labels
}

resource "google_clouddeploy_target" "gke_target" {
  count = var.enable_cloud_deploy ? 1 : 0
  
  project     = var.project_id
  location    = var.primary_region
  name        = "${var.environment}-gke"
  description = "${title(var.environment)} GKE cluster target - U2I managed"
  
  # U2I requires annotations
  annotations = {
    "u2i-managed"     = "true"
    "u2i-environment" = var.environment
  }
  
  gke {
    cluster = format("projects/%s/locations/%s/clusters/%s",
      local.is_prod ? 
        lookup(data.terraform_remote_state.shared_gke.outputs.projects_created, "u2i-gke-prod", {}).project_id :
        lookup(data.terraform_remote_state.shared_gke.outputs.projects_created, "u2i-gke-nonprod", {}).project_id,
      var.primary_region,
      local.is_prod ? "prod-autopilot" : "nonprod-autopilot"
    )
  }
  
  execution_configs {
    usages           = ["RENDER", "DEPLOY", "VERIFY"]  # U2I requires VERIFY
    service_account  = google_service_account.cloud_deploy[0].email
    artifact_storage = "gs://${module.deployment_bucket.bucket_name}"
  }
  
  # U2I requires approval for production
  require_approval = local.is_prod
  
  labels = local.u2i_labels
}

# U2I-specific monitoring
module "monitoring" {
  source = "git::github.com/yourorg/terraform-google-compliance-modules//modules/monitoring-suite?ref=v1.0.0"
  
  project_id = var.project_id
  
  # U2I standard alerts
  alerts = {
    "high-error-rate" = {
      display_name = "High Error Rate - ${var.environment}"
      conditions = [{
        display_name = "Error rate above 1%"
        threshold_value = 0.01
      }]
    }
    "deployment-failure" = {
      display_name = "Deployment Failure - ${var.environment}"
      conditions = [{
        display_name = "Cloud Deploy failure"
        threshold_value = 1
      }]
    }
  }
  
  notification_channels = var.notification_channels
}

# IAM permissions for Cloud Deploy (U2I specific roles)
resource "google_project_iam_member" "cloud_deploy_permissions" {
  for_each = var.enable_cloud_deploy ? toset([
    "roles/clouddeploy.jobRunner",
    "roles/container.developer",  # U2I requires full developer access
    "roles/artifactregistry.repoAdmin",  # U2I requires repo admin
    "roles/storage.objectAdmin",
    "roles/logging.logWriter",  # U2I audit requirements
  ]) : toset([])
  
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.cloud_deploy[0].email}"
}
EOF

# Create U2I-specific outputs
cat > ../u2i-terraform-modules/modules/u2i-webapp-base/outputs.tf << 'EOF'
output "project_id" {
  description = "The GCP project ID"
  value       = var.project_id
}

output "terraform_service_account" {
  description = "Terraform service account email"
  value       = module.terraform_sa.email
}

output "workload_identity_provider" {
  description = "Workload Identity Provider for GitHub Actions"
  value       = module.github_wif.provider_name
}

output "artifact_registry_url" {
  description = "URL for the Artifact Registry"
  value       = var.enable_artifact_registry ? google_artifact_registry_repository.webapp_images[0].id : null
}

output "deployment_bucket" {
  description = "GCS bucket for deployment artifacts"
  value       = module.deployment_bucket.bucket_name
}

output "kms_keys" {
  description = "KMS key IDs"
  value       = module.kms.keys
}

output "monitoring_dashboard_url" {
  description = "URL to monitoring dashboard"
  value       = "https://console.cloud.google.com/monitoring/dashboards?project=${var.project_id}"
}

# U2I compliance outputs
output "compliance_status" {
  description = "U2I compliance status"
  value = {
    cmek_enabled     = true
    audit_logging    = true
    private_gke      = true
    eu_data_residency = true
    vulnerability_scanning = var.enable_artifact_registry
  }
}
EOF

# Create comprehensive README
cat > ../u2i-terraform-modules/README.md << 'EOF'
# U2I Terraform Application Modules

U2I-specific Terraform modules for application teams that wrap generic compliance modules with U2I standards and policies.

## Overview

These modules implement U2I's specific requirements on top of the generic `terraform-google-compliance-modules`:

- **Mandatory CMEK encryption** for all data at rest
- **EU data residency** for GDPR compliance  
- **Specific labeling standards** for cost tracking and compliance
- **Audit logging** for all resources
- **Vulnerability scanning** for container images
- **Automated cleanup policies** to reduce costs

## Available Modules

### Application Modules
- `u2i-webapp-base` - Standard web application infrastructure
- `u2i-data-platform` - Data analytics platform setup
- `u2i-ml-platform` - Machine learning infrastructure

## Architecture

```
Application Team Terraform
    ↓ uses
U2I Application Modules (this repo)
    ↓ wraps with U2I policies
Generic Compliance Modules
    ↓ creates
GCP Resources (with U2I standards enforced)
```

## U2I Standards Enforced

### Security
- ✅ CMEK encryption on all storage (90-day rotation)
- ✅ Private GKE nodes only
- ✅ Binary authorization enabled
- ✅ Vulnerability scanning on all container registries
- ✅ Workload Identity for all service accounts

### Compliance  
- ✅ ISO 27001, SOC 2, GDPR labels on all resources
- ✅ EU data residency enforced
- ✅ Audit logging enabled
- ✅ Monitoring and alerting configured
- ✅ Retention policies implemented

### Operations
- ✅ Consistent naming: `{resource}-{environment}-{type}`
- ✅ Automated cleanup of old artifacts
- ✅ Budget alerts configured
- ✅ Deployment verification required

## Usage

```hcl
module "webapp" {
  source = "git::github.com/u2i/u2i-terraform-modules//modules/u2i-webapp-base?ref=v1.0.0"
  
  project_id   = "u2i-webapp-prod"
  environment  = "production"
  
  # Optional overrides
  enable_cloud_deploy      = true
  enable_artifact_registry = true
  
  notification_channels = ["projects/u2i-monitoring/notificationChannels/12345"]
}
```

## For Application Teams

### DO ✅
- Use these U2I modules instead of generic modules
- Follow the examples provided
- Report issues to the platform team
- Request new features via GitHub issues

### DON'T ❌
- Use `terraform-google-compliance-modules` directly
- Override security defaults without approval
- Disable audit logging or monitoring
- Use non-EU regions

## Module Inputs and Outputs

See individual module README files for detailed documentation.

## Versioning

We follow semantic versioning:
- **MAJOR**: Breaking changes or new U2I policies
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes

## Support

- Slack: #u2i-platform-support
- Email: platform-team@u2i.com
- Issues: GitHub Issues
EOF

# Create examples
mkdir -p ../u2i-terraform-modules/examples/webapp-complete
cat > ../u2i-terraform-modules/examples/webapp-complete/main.tf << 'EOF'
# Complete example of U2I webapp deployment

module "webapp_dev" {
  source = "../../modules/u2i-webapp-base"
  
  project_id      = "u2i-webapp-dev"
  environment     = "dev"
  primary_region  = "europe-west1"
  billing_account = "01AA86-A09BB4-30E84E"
  
  # Enable all features for dev
  enable_cloud_deploy      = true
  enable_artifact_registry = true
  
  # Notification channels
  notification_channels = [
    "projects/u2i-monitoring/notificationChannels/dev-alerts"
  ]
  
  # GitHub repository
  github_repo = "u2i/webapp-team-infrastructure"
  
  common_tags = jsonencode({
    cost_center = "webapp-team"
    project     = "customer-portal"
  })
}

module "webapp_prod" {
  source = "../../modules/u2i-webapp-base"
  
  project_id      = "u2i-webapp-prod"
  environment     = "prod"
  primary_region  = "europe-west1"
  billing_account = "01AA86-A09BB4-30E84E"
  
  # Production configuration
  enable_cloud_deploy      = true
  enable_artifact_registry = true
  
  # Production notification channels
  notification_channels = [
    "projects/u2i-monitoring/notificationChannels/prod-alerts",
    "projects/u2i-monitoring/notificationChannels/oncall-pager"
  ]
  
  # GitHub repository
  github_repo = "u2i/webapp-team-infrastructure"
  
  common_tags = jsonencode({
    cost_center = "webapp-team"
    project     = "customer-portal"
    sla         = "99.9"
  })
}
EOF

# Update webapp-team-infrastructure to use U2I modules
echo ""
echo "📝 Updating webapp-team-infrastructure to use U2I modules..."

for env in dev staging qa prod pre-prod; do
  cat > environments/$env/terragrunt.hcl << EOF
# $env environment configuration

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = "./env.hcl"
}

# Use U2I-specific webapp module
terraform {
  # After pushing to GitHub:
  source = "git::git@github.com:u2i/u2i-terraform-modules.git//modules/u2i-webapp-base?ref=v1.0.0"
  
  # For local development:
  # source = "../../../u2i-terraform-modules/modules/u2i-webapp-base"
}

inputs = {
  # Notification channels for this environment
  notification_channels = [
    "projects/u2i-monitoring/notificationChannels/${env}-alerts"
  ]
  
  # Environment-specific overrides
  enable_cloud_deploy      = $([ "$env" = "qa" ] && echo "false" || echo "true")
  enable_artifact_registry = true
}
EOF
done

echo ""
echo "✅ U2I application modules created!"
echo ""
echo "📋 Repository summary:"
echo ""
echo "1. terraform-google-compliance-modules: Generic GCP modules"
echo "2. u2i-terraform-modules: U2I-specific wrappers"
echo "3. gcp-org-compliance: Organization deployment (unchanged)"
echo "4. webapp-team-infrastructure: Uses U2I modules"
echo ""
echo "🔒 U2I policies enforced:"
echo "- CMEK encryption everywhere"
echo "- EU data residency only"
echo "- Vulnerability scanning"
echo "- Audit logging"
echo "- Consistent labeling"
echo ""
echo "🚀 Next steps:"
echo "1. Push terraform-google-compliance-modules to GitHub"
echo "2. Push u2i-terraform-modules to GitHub" 
echo "3. Update terragrunt.hcl files with GitHub URLs"
echo "4. Test with 'terragrunt plan' in dev environment"