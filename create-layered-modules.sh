#!/bin/bash
# Script to create layered module structure

set -e

echo "🚀 Creating layered module structure"
echo "===================================="

# Create base modules repository
echo "📦 Creating terraform-modules-base (generic/reusable)..."
mkdir -p ../terraform-modules-base/modules/{compute,networking,data,security}

# Example: Generic GKE module
mkdir -p ../terraform-modules-base/modules/compute/gke-autopilot
cat > ../terraform-modules-base/modules/compute/gke-autopilot/main.tf << 'EOF'
# Generic GKE Autopilot Module
# Can be used by any organization

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "network_config" {
  description = "Network configuration"
  type = object({
    vpc_name                = string
    subnet_name             = string
    enable_private_nodes    = bool
    enable_private_endpoint = bool
    master_cidr            = string
  })
  default = {
    vpc_name                = "default"
    subnet_name             = "default"
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_cidr            = "172.16.0.0/28"
  }
}

variable "security_config" {
  description = "Security configuration"
  type = object({
    enable_shielded_nodes         = bool
    enable_binary_authorization   = bool
    enable_network_policy         = bool
    database_encryption_key       = string
  })
  default = {
    enable_shielded_nodes         = true
    enable_binary_authorization   = false
    enable_network_policy         = true
    database_encryption_key       = null
  }
}

resource "google_container_cluster" "main" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id
  
  enable_autopilot = true
  
  network    = var.network_config.vpc_name
  subnetwork = var.network_config.subnet_name
  
  private_cluster_config {
    enable_private_nodes    = var.network_config.enable_private_nodes
    enable_private_endpoint = var.network_config.enable_private_endpoint
    master_ipv4_cidr_block  = var.network_config.master_cidr
  }
  
  dynamic "database_encryption" {
    for_each = var.security_config.database_encryption_key != null ? [1] : []
    content {
      state    = "ENCRYPTED"
      key_name = var.security_config.database_encryption_key
    }
  }
  
  dynamic "binary_authorization" {
    for_each = var.security_config.enable_binary_authorization ? [1] : []
    content {
      evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
    }
  }
  
  release_channel {
    channel = "REGULAR"
  }
}

output "cluster_id" {
  value = google_container_cluster.main.id
}

output "cluster_endpoint" {
  value = google_container_cluster.main.endpoint
}
EOF

# Create U2I-specific modules repository
echo ""
echo "📦 Creating u2i-terraform-modules (organization-specific)..."
mkdir -p ../u2i-terraform-modules/modules/{u2i-gke-compliant,u2i-webapp-base,u2i-data-platform}

# U2I GKE Compliant Module (wraps generic + adds U2I policies)
cat > ../u2i-terraform-modules/modules/u2i-gke-compliant/main.tf << 'EOF'
# U2I Compliant GKE Module
# Wraps generic GKE module with U2I-specific requirements

module "gke_base" {
  source = "git::git@github.com:yourorg/terraform-modules-base.git//modules/compute/gke-autopilot?ref=v1.0.0"
  
  cluster_name = var.cluster_name
  project_id   = var.project_id
  region       = var.region
  
  # U2I-mandated network configuration
  network_config = {
    vpc_name                = var.vpc_name
    subnet_name             = var.subnet_name
    enable_private_nodes    = true  # Always required for U2I
    enable_private_endpoint = false # Public endpoint for CI/CD
    master_cidr            = "10.100.0.0/28" # U2I standard range
  }
  
  # U2I-mandated security configuration
  security_config = {
    enable_shielded_nodes       = true  # Always required
    enable_binary_authorization = true  # Always required
    enable_network_policy       = true  # Always required
    database_encryption_key     = var.kms_key_id # CMEK required
  }
}

# Additional U2I-specific configurations
resource "google_binary_authorization_policy" "u2i_policy" {
  project = var.project_id
  
  admission_whitelist_patterns {
    name_pattern = "gcr.io/${var.project_id}/*"
  }
  
  admission_whitelist_patterns {
    name_pattern = "europe-west1-docker.pkg.dev/${var.project_id}/*"
  }
  
  default_admission_rule {
    evaluation_mode  = "REQUIRE_ATTESTATION"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    
    require_attestations_by = [
      "projects/${var.project_id}/attestors/prod-attestor"
    ]
  }
}

# U2I compliance labels
locals {
  u2i_labels = {
    compliance     = "iso27001-soc2-gdpr"
    data_residency = "eu"
    managed_by     = "terraform"
    organization   = "u2i"
  }
}

resource "null_resource" "label_cluster" {
  provisioner "local-exec" {
    command = <<-EOT
      gcloud container clusters update ${module.gke_base.cluster_id} \
        --update-labels=${join(",", [for k, v in local.u2i_labels : "${k}=${v}"])}
    EOT
  }
}
EOF

# Create README for base modules
cat > ../terraform-modules-base/README.md << 'EOF'
# Terraform Base Modules

Generic, reusable Terraform modules that can be used across different organizations and customers.

## Design Principles

1. **Generic** - No organization-specific assumptions
2. **Configurable** - Extensive use of variables
3. **Secure by Default** - Security best practices as defaults
4. **Cloud-Native** - Follow cloud provider best practices

## Module Categories

### Compute
- `gke-autopilot` - Google Kubernetes Engine Autopilot clusters
- `cloud-run` - Serverless container deployments
- `compute-mig` - Managed instance groups

### Networking  
- `vpc-shared` - Shared VPC configuration
- `vpc-peering` - VPC peering setup
- `load-balancer` - Load balancer configuration

### Data
- `cloud-sql` - Managed SQL databases
- `gcs-bucket` - Cloud Storage buckets
- `bigquery-dataset` - BigQuery datasets

### Security
- `kms` - Key Management Service
- `iam-workload-identity` - Workload Identity Federation
- `secret-manager` - Secret management

## Usage

These modules are meant to be wrapped by organization-specific modules that add:
- Compliance requirements
- Security policies  
- Naming conventions
- Network configurations
- Label standards

## Versioning

Strict semantic versioning:
- MAJOR: Breaking changes to variables/resources
- MINOR: New optional features
- PATCH: Bug fixes only
EOF

# Create README for U2I modules
cat > ../u2i-terraform-modules/README.md << 'EOF'
# U2I Terraform Modules

Organization-specific modules that wrap generic base modules with U2I policies and standards.

## Architecture

```
Your Code (environments/dev/)
    ↓ uses
U2I Modules (u2i-webapp-base)
    ↓ wraps
Base Modules (gke-autopilot)
    ↓ creates
GCP Resources
```

## U2I Standards Applied

1. **Security**
   - CMEK encryption on all data
   - Private GKE nodes
   - Binary authorization
   - Shielded VMs

2. **Compliance**
   - ISO 27001 labels
   - SOC 2 controls
   - GDPR data residency (EU)
   - Audit logging

3. **Networking**
   - Specific IP ranges
   - Private service connect
   - VPC service controls

4. **Operations**
   - Mandatory monitoring
   - Budget alerts
   - Backup policies

## Available Modules

- `u2i-gke-compliant` - GKE with U2I security policies
- `u2i-webapp-base` - Standard web application setup
- `u2i-data-platform` - Data analytics platform
- `u2i-org-baseline` - Organization-level setup

## For Other Customers

To create similar structure for another customer:

1. Fork `terraform-modules-base`
2. Create `customer-terraform-modules`
3. Wrap base modules with customer policies
4. Use in customer environments
EOF

echo ""
echo "✅ Layered module structure created!"
echo ""
echo "📋 Structure summary:"
echo "1. terraform-modules-base: Generic modules (public/shareable)"
echo "2. u2i-terraform-modules: U2I-specific wrappers"
echo "3. webapp-team-infrastructure: Actual deployments"
echo ""
echo "🔄 To apply this pattern for another customer:"
echo "1. They use the same terraform-modules-base"
echo "2. Create customer-terraform-modules with their policies"
echo "3. Deploy using their specific requirements"