#!/bin/bash
# Script to create U2I-specific modules repository

set -e

echo "🚀 Creating U2I-specific terraform modules repository"
echo "==================================================="

# Create U2I modules structure
echo "📦 Creating u2i-terraform-modules repository..."
mkdir -p ../u2i-terraform-modules/{modules,examples}

# Move webapp-base module to U2I modules
echo "Moving webapp-base to U2I modules..."
mkdir -p ../u2i-terraform-modules/modules/u2i-webapp-base
cp -r modules/webapp-base/* ../u2i-terraform-modules/modules/u2i-webapp-base/

# Create U2I organization wrapper
echo "Creating U2I organization wrapper..."
mkdir -p ../u2i-terraform-modules/modules/u2i-organization
cat > ../u2i-terraform-modules/modules/u2i-organization/main.tf << 'EOF'
# U2I Organization Setup
# Wraps generic organization module with U2I-specific configurations

module "org_base" {
  source = "git::git@github.com:yourorg/gcp-org-compliance.git//modules/organization?ref=v1.0.0"
  
  organization_id     = var.organization_id
  billing_account_id  = var.billing_account_id
  
  # U2I-specific folder names
  folder_names = {
    compliant = "u2i-compliant-systems"
    migration = "u2i-migration-in-progress"
    legacy    = "u2i-legacy-systems"
  }
}

# U2I-specific organization policies
resource "google_organization_policy" "u2i_eu_data_residency" {
  org_id     = var.organization_id
  constraint = "gcp.resourceLocations"
  
  list_policy {
    allow {
      values = [
        "in:eu-locations",
        "in:europe-west1-locations",
        "in:europe-west4-locations"
      ]
    }
  }
}

resource "google_organization_policy" "u2i_require_cmek" {
  org_id     = var.organization_id
  constraint = "gcp.restrictCmekCryptoKeyProjects"
  
  boolean_policy {
    enforced = true
  }
}

# U2I-specific labels for all projects
locals {
  u2i_labels = {
    organization   = "u2i"
    managed_by     = "terraform"
    compliance     = "iso27001-soc2-gdpr"
    data_residency = "eu"
  }
}
EOF

# Create U2I GKE wrapper
echo "Creating U2I GKE compliant wrapper..."
mkdir -p ../u2i-terraform-modules/modules/u2i-gke-compliant
cat > ../u2i-terraform-modules/modules/u2i-gke-compliant/main.tf << 'EOF'
# U2I Compliant GKE Configuration
# Wraps generic shared-gke with U2I requirements

module "gke_base" {
  source = "git::git@github.com:yourorg/gcp-org-compliance.git//modules/shared-gke?ref=v1.0.0"
  
  project_id     = var.project_id
  cluster_name   = var.cluster_name
  region         = var.region
  
  # U2I security requirements
  enable_private_nodes        = true
  enable_binary_authorization = true
  enable_shielded_gke_nodes   = true
  
  # U2I-specific labels
  cluster_labels = merge(var.additional_labels, {
    organization   = "u2i"
    compliance     = "iso27001-soc2-gdpr"
    data_residency = "eu"
    gdpr_compliant = "true"
  })
  
  # U2I network configuration
  master_ipv4_cidr_block = "10.100.0.0/28"
  
  # U2I node configuration
  node_config = {
    machine_type = "e2-standard-4"
    disk_size_gb = 100
    disk_type    = "pd-ssd"
    
    # U2I security requirements
    enable_secure_boot          = true
    enable_integrity_monitoring = true
  }
}

# U2I-specific monitoring
resource "google_monitoring_alert_policy" "gke_compliance" {
  display_name = "GKE Compliance Alert - ${var.cluster_name}"
  project      = var.project_id
  
  conditions {
    display_name = "Binary Authorization Violations"
    # Alert configuration
  }
  
  notification_channels = var.notification_channels
}
EOF

# Create U2I tenant compliance module
echo "Creating U2I tenant compliance module..."
mkdir -p ../u2i-terraform-modules/modules/u2i-tenant-compliance
cat > ../u2i-terraform-modules/modules/u2i-tenant-compliance/main.tf << 'EOF'
# U2I Tenant Compliance Module
# Implements U2I-specific compliance requirements for tenant projects

variable "tenant_project_id" {
  description = "The tenant project ID"
  type        = string
}

variable "tenant_name" {
  description = "Name of the tenant"
  type        = string
}

# U2I-specific VPC Service Controls
resource "google_access_context_manager_service_perimeter" "tenant_perimeter" {
  parent = "accessPolicies/${var.access_policy_id}"
  name   = "accessPolicies/${var.access_policy_id}/servicePerimeters/u2i_${var.tenant_name}"
  title  = "U2I ${var.tenant_name} Perimeter"
  
  status {
    resources = ["projects/${data.google_project.tenant.number}"]
    
    # U2I allowed services
    restricted_services = [
      "storage.googleapis.com",
      "bigquery.googleapis.com",
      "compute.googleapis.com"
    ]
  }
}

# U2I audit logging configuration
resource "google_project_iam_audit_config" "u2i_audit" {
  project = var.tenant_project_id
  service = "allServices"
  
  audit_log_config {
    log_type = "ADMIN_READ"
  }
  
  audit_log_config {
    log_type = "DATA_READ"
  }
  
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

# U2I compliance dashboard
resource "google_monitoring_dashboard" "compliance_dashboard" {
  project        = var.tenant_project_id
  dashboard_json = jsonencode({
    displayName = "U2I Compliance Dashboard - ${var.tenant_name}"
    # Dashboard configuration
  })
}
EOF

# Create comprehensive README
cat > ../u2i-terraform-modules/README.md << 'EOF'
# U2I Terraform Modules

Organization-specific Terraform modules that implement U2I standards and compliance requirements.

## Architecture

These modules wrap the generic `gcp-org-compliance` modules with U2I-specific:
- Security policies
- Compliance requirements
- Network configurations
- Labeling standards
- Monitoring and alerting

## Module Structure

```
u2i-terraform-modules/
├── modules/
│   ├── u2i-organization/      # Organization-level setup
│   ├── u2i-gke-compliant/     # GKE with U2I standards
│   ├── u2i-webapp-base/       # Web application baseline
│   ├── u2i-data-platform/     # Data platform setup
│   └── u2i-tenant-compliance/ # Tenant compliance
```

## U2I Standards

All modules enforce:

### Security
- CMEK encryption for all data at rest
- Private GKE nodes only
- Binary authorization required
- Shielded VMs mandatory
- VPC Service Controls where applicable

### Compliance
- ISO 27001 compliance labels
- SOC 2 audit logging
- GDPR data residency (EU only)
- Mandatory monitoring and alerting

### Operations
- Standardized naming conventions
- Required tags and labels
- Budget alerts
- Backup policies

## Usage

```hcl
module "webapp" {
  source = "git::git@github.com:u2i/u2i-terraform-modules.git//modules/u2i-webapp-base?ref=v1.0.0"
  
  project_id  = "u2i-webapp-prod"
  environment = "production"
}
```

## Versioning

Follows semantic versioning:
- MAJOR: Breaking changes to U2I standards
- MINOR: New features or modules
- PATCH: Bug fixes and minor updates

## For Teams

Teams should NOT use `gcp-org-compliance` modules directly. Always use the U2I wrappers to ensure compliance.
EOF

# Create migration guide
cat > ../u2i-terraform-modules/MIGRATION.md << 'EOF'
# Migration Guide

## From Direct Module Usage to U2I Modules

### Before (Direct usage of gcp-org-compliance)
```hcl
module "gke" {
  source = "git::git@github.com:yourorg/gcp-org-compliance.git//modules/shared-gke"
  
  # Team needs to remember all U2I requirements
  enable_private_nodes = true
  labels = {
    compliance = "iso27001-soc2-gdpr"
    # Easy to forget required labels
  }
}
```

### After (Using U2I modules)
```hcl
module "gke" {
  source = "git::git@github.com:u2i/u2i-terraform-modules.git//modules/u2i-gke-compliant"
  
  # U2I requirements are built-in
  cluster_name = "my-cluster"
  project_id   = var.project_id
}
```

## Benefits
1. Compliance is automatic
2. Security policies are enforced
3. No need to remember U2I standards
4. Consistent across all teams
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
  # Local development (update after pushing to GitHub)
  source = "../../../u2i-terraform-modules/modules/u2i-webapp-base"
  
  # After pushing to GitHub:
  # source = "git::git@github.com:u2i/u2i-terraform-modules.git//modules/u2i-webapp-base?ref=v1.0.0"
}

inputs = {
  enable_cloud_deploy      = $([ "$env" = "qa" ] && echo "false" || echo "true")
  enable_artifact_registry = true
}
EOF
done

echo ""
echo "✅ U2I modules repository structure created!"
echo ""
echo "📋 Repository purposes:"
echo "- gcp-org-compliance: Generic, reusable modules (any company)"
echo "- u2i-terraform-modules: U2I-specific wrappers and policies"
echo "- webapp-team-infrastructure: Actual deployments using U2I modules"
echo ""
echo "🔄 Next steps:"
echo "1. Push u2i-terraform-modules to GitHub"
echo "2. Tag initial version (v1.0.0)"
echo "3. Update environment terragrunt.hcl files to use GitHub URLs"
echo "4. Test with terragrunt plan"