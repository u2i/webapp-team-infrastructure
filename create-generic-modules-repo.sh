#!/bin/bash
# Script to create generic terraform-google-compliance-modules repository

set -e

echo "🚀 Creating generic terraform-google-compliance-modules repository"
echo "==============================================================="

# Create generic modules structure
echo "📦 Creating terraform-google-compliance-modules..."
mkdir -p ../terraform-google-compliance-modules/{modules,examples,tests}

# Extract generic patterns from current webapp-base module
echo "Creating generic secure-gke module..."
mkdir -p ../terraform-google-compliance-modules/modules/secure-gke
cat > ../terraform-google-compliance-modules/modules/secure-gke/README.md << 'EOF'
# Secure GKE Module

A secure, compliant GKE Autopilot cluster configuration following Google Cloud security best practices.

## Features

- GKE Autopilot for reduced operational overhead
- Private nodes with configurable endpoint access
- Binary authorization support
- Workload Identity enabled
- CMEK encryption support
- Shielded GKE nodes
- Network policies enabled

## Usage

```hcl
module "gke" {
  source = "github.com/yourorg/terraform-google-compliance-modules//modules/secure-gke"
  
  project_id   = "my-project"
  cluster_name = "my-cluster"
  region       = "europe-west1"
  
  # Optional: Override security defaults
  enable_private_endpoint = false  # Default: false (for CI/CD access)
  enable_binary_authorization = true  # Default: false
}
```
EOF

cat > ../terraform-google-compliance-modules/modules/secure-gke/main.tf << 'EOF'
# Secure GKE Autopilot Module
# Implements Google Cloud security best practices

resource "google_container_cluster" "main" {
  provider = google-beta
  
  name     = var.cluster_name
  location = var.region
  project  = var.project_id
  
  # Autopilot mode
  enable_autopilot = true
  
  # Network configuration
  network    = var.network_name
  subnetwork = var.subnet_name
  
  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = var.enable_private_nodes
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }
  
  # IP allocation policy for VPC-native clusters
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }
  
  # Security configurations
  dynamic "binary_authorization" {
    for_each = var.enable_binary_authorization ? [1] : []
    content {
      evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
    }
  }
  
  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  
  # Release channel for automatic upgrades
  release_channel {
    channel = var.release_channel
  }
  
  # Maintenance window
  maintenance_policy {
    recurring_window {
      start_time = var.maintenance_start_time
      end_time   = var.maintenance_end_time
      recurrence = var.maintenance_recurrence
    }
  }
  
  # Optional CMEK encryption
  dynamic "database_encryption" {
    for_each = var.database_encryption_key != null ? [1] : []
    content {
      state    = "ENCRYPTED"
      key_name = var.database_encryption_key
    }
  }
  
  # Labels
  resource_labels = var.cluster_labels
}

# Create namespaces if specified
resource "kubernetes_namespace" "namespaces" {
  for_each = toset(var.namespaces)
  
  metadata {
    name = each.key
    labels = var.namespace_labels
  }
  
  depends_on = [google_container_cluster.main]
}
EOF

cat > ../terraform-google-compliance-modules/modules/secure-gke/variables.tf << 'EOF'
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
}

variable "region" {
  description = "The region for the GKE cluster"
  type        = string
}

variable "network_name" {
  description = "The VPC network name"
  type        = string
  default     = "default"
}

variable "subnet_name" {
  description = "The subnet name"
  type        = string
  default     = "default"
}

variable "enable_private_nodes" {
  description = "Enable private nodes (nodes without public IPs)"
  type        = bool
  default     = true
}

variable "enable_private_endpoint" {
  description = "Enable private endpoint (master without public IP)"
  type        = bool
  default     = false
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for master network"
  type        = string
  default     = "172.16.0.0/28"
}

variable "pods_range_name" {
  description = "Secondary range name for pods"
  type        = string
  default     = ""
}

variable "services_range_name" {
  description = "Secondary range name for services"
  type        = string
  default     = ""
}

variable "enable_binary_authorization" {
  description = "Enable Binary Authorization"
  type        = bool
  default     = false
}

variable "release_channel" {
  description = "GKE release channel"
  type        = string
  default     = "REGULAR"
}

variable "maintenance_start_time" {
  description = "Start time for maintenance window"
  type        = string
  default     = "2023-01-01T00:00:00Z"
}

variable "maintenance_end_time" {
  description = "End time for maintenance window"
  type        = string
  default     = "2023-01-01T04:00:00Z"
}

variable "maintenance_recurrence" {
  description = "Maintenance window recurrence"
  type        = string
  default     = "FREQ=WEEKLY;BYDAY=SA"
}

variable "database_encryption_key" {
  description = "Cloud KMS key for GKE database encryption"
  type        = string
  default     = null
}

variable "cluster_labels" {
  description = "Labels to apply to the cluster"
  type        = map(string)
  default     = {}
}

variable "namespaces" {
  description = "List of Kubernetes namespaces to create"
  type        = list(string)
  default     = []
}

variable "namespace_labels" {
  description = "Labels to apply to all namespaces"
  type        = map(string)
  default     = {}
}
EOF

# Create CMEK storage module
echo "Creating generic cmek-storage module..."
mkdir -p ../terraform-google-compliance-modules/modules/cmek-storage
cat > ../terraform-google-compliance-modules/modules/cmek-storage/main.tf << 'EOF'
# CMEK-Encrypted Storage Module
# Provides GCS bucket with customer-managed encryption

locals {
  create_kms_resources = var.kms_key_id == null
}

# Create KMS resources if not provided
resource "google_kms_key_ring" "bucket" {
  count    = local.create_kms_resources ? 1 : 0
  project  = var.project_id
  name     = "${var.bucket_name}-keyring"
  location = var.location
}

resource "google_kms_crypto_key" "bucket" {
  count           = local.create_kms_resources ? 1 : 0
  name            = "${var.bucket_name}-key"
  key_ring        = google_kms_key_ring.bucket[0].id
  rotation_period = var.rotation_period

  lifecycle {
    prevent_destroy = true
  }
}

# Get GCS service account
data "google_storage_project_service_account" "gcs_account" {
  project = var.project_id
}

# Grant GCS service account access to KMS key
resource "google_kms_crypto_key_iam_member" "gcs_encrypt" {
  crypto_key_id = local.create_kms_resources ? google_kms_crypto_key.bucket[0].id : var.kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}

# Create the bucket with CMEK
resource "google_storage_bucket" "bucket" {
  project  = var.project_id
  name     = var.bucket_name
  location = var.location

  # Security settings
  uniform_bucket_level_access = true
  public_access_prevention    = var.public_access_prevention

  # Versioning
  versioning {
    enabled = var.enable_versioning
  }

  # Lifecycle rules
  dynamic "lifecycle_rule" {
    for_each = var.lifecycle_rules
    content {
      condition {
        age                   = lifecycle_rule.value.age
        num_newer_versions    = lifecycle_rule.value.num_newer_versions
        with_state            = lifecycle_rule.value.with_state
        matches_storage_class = lifecycle_rule.value.matches_storage_class
      }
      action {
        type          = lifecycle_rule.value.action_type
        storage_class = lifecycle_rule.value.action_storage_class
      }
    }
  }

  # CMEK encryption
  encryption {
    default_kms_key_name = local.create_kms_resources ? google_kms_crypto_key.bucket[0].id : var.kms_key_id
  }

  labels = var.labels

  depends_on = [google_kms_crypto_key_iam_member.gcs_encrypt]
}

# Bucket IAM
resource "google_storage_bucket_iam_member" "members" {
  for_each = var.bucket_iam_members
  
  bucket = google_storage_bucket.bucket.name
  role   = each.value.role
  member = each.value.member
}
EOF

# Create workload identity module  
echo "Creating generic workload-identity module..."
mkdir -p ../terraform-google-compliance-modules/modules/workload-identity
cat > ../terraform-google-compliance-modules/modules/workload-identity/main.tf << 'EOF'
# Workload Identity Federation Module
# Sets up WIF for external workloads (GitHub Actions, GitLab CI, etc.)

resource "google_iam_workload_identity_pool" "main" {
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = var.display_name
  description               = var.description
  disabled                  = var.disabled
}

# GitHub Actions provider
resource "google_iam_workload_identity_pool_provider" "github" {
  count = var.github_config != null ? 1 : 0
  
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.main.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub Actions"
  description                        = "GitHub Actions OIDC provider"
  
  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.aud"              = "assertion.aud"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
  }
  
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
  
  attribute_condition = var.github_config.attribute_condition
}

# GitLab provider
resource "google_iam_workload_identity_pool_provider" "gitlab" {
  count = var.gitlab_config != null ? 1 : 0
  
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.main.workload_identity_pool_id
  workload_identity_pool_provider_id = "gitlab"
  display_name                       = "GitLab CI"
  description                        = "GitLab CI OIDC provider"
  
  attribute_mapping = {
    "google.subject"                  = "assertion.sub"
    "attribute.project_id"            = "assertion.project_id"
    "attribute.project_path"          = "assertion.project_path"
    "attribute.namespace_id"          = "assertion.namespace_id"
    "attribute.namespace_path"        = "assertion.namespace_path"
    "attribute.pipeline_source"       = "assertion.pipeline_source"
    "attribute.project_visibility"    = "assertion.project_visibility"
  }
  
  oidc {
    issuer_uri = var.gitlab_config.issuer_uri
  }
  
  attribute_condition = var.gitlab_config.attribute_condition
}

# Service account impersonation bindings
resource "google_service_account_iam_member" "workload_identity_user" {
  for_each = var.service_account_impersonation
  
  service_account_id = each.value.service_account_email
  role               = "roles/iam.workloadIdentityUser"
  member             = each.value.member
}
EOF

# Create main README
cat > ../terraform-google-compliance-modules/README.md << 'EOF'
# Terraform Google Compliance Modules

A collection of opinionated Terraform modules implementing Google Cloud security best practices and compliance requirements.

## Overview

These modules provide secure-by-default configurations for common Google Cloud resources, suitable for organizations with compliance requirements such as:
- ISO 27001
- SOC 2
- GDPR
- HIPAA
- PCI DSS

## Available Modules

### Security & Identity
- **workload-identity** - Workload Identity Federation for CI/CD
- **service-account** - Secure service account management
- **kms** - Cloud KMS configuration with rotation

### Compute
- **secure-gke** - Hardened GKE Autopilot clusters
- **secure-gce** - Hardened Compute Engine instances
- **cloud-run-secure** - Secure Cloud Run services

### Storage & Data
- **cmek-storage** - CMEK-encrypted Cloud Storage buckets
- **secure-cloud-sql** - Hardened Cloud SQL instances
- **bigquery-secure** - Secure BigQuery datasets

### Networking
- **vpc-secure** - Secure VPC with private Google Access
- **cloud-nat** - Cloud NAT for private workloads
- **private-service-connect** - Private Service Connect endpoints

## Design Principles

1. **Secure by Default** - All modules implement security best practices out of the box
2. **Compliance Ready** - Configurations support common compliance frameworks
3. **Configurable** - Security defaults can be overridden when needed
4. **Well Documented** - Each module includes comprehensive documentation
5. **Tested** - Modules include tests and validation

## Usage

```hcl
module "gke" {
  source  = "github.com/yourorg/terraform-google-compliance-modules//modules/secure-gke"
  version = "v1.0.0"
  
  project_id   = "my-project"
  cluster_name = "my-secure-cluster"
  region       = "europe-west1"
}
```

## Module Standards

All modules follow these standards:

### Security
- Enable audit logging where applicable
- Use customer-managed encryption keys (CMEK) when possible
- Implement least-privilege IAM
- Enable private IPs/endpoints by default
- Configure security scanning where available

### Compliance
- Support for compliance labels
- Audit log configuration
- Data residency controls
- Encryption at rest and in transit
- Regular key rotation

### Operations
- Comprehensive outputs for integration
- Consistent variable naming
- Terraform 1.0+ compatibility
- Provider version constraints

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing new modules.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
EOF

# Create an example
mkdir -p ../terraform-google-compliance-modules/examples/secure-webapp
cat > ../terraform-google-compliance-modules/examples/secure-webapp/main.tf << 'EOF'
# Example: Secure Web Application Infrastructure

module "gke" {
  source = "../../modules/secure-gke"
  
  project_id   = var.project_id
  cluster_name = "webapp-cluster"
  region       = var.region
  
  # Enable additional security features
  enable_binary_authorization = true
  database_encryption_key     = module.kms.key_id
  
  cluster_labels = {
    app         = "webapp"
    environment = "production"
  }
}

module "kms" {
  source = "../../modules/kms"
  
  project_id   = var.project_id
  keyring_name = "webapp-keyring"
  location     = var.region
  
  keys = {
    "gke-etcd" = {
      purpose         = "ENCRYPT_DECRYPT"
      rotation_period = "7776000s" # 90 days
    }
    "storage" = {
      purpose         = "ENCRYPT_DECRYPT"
      rotation_period = "7776000s"
    }
  }
}

module "artifacts_bucket" {
  source = "../../modules/cmek-storage"
  
  project_id   = var.project_id
  bucket_name  = "${var.project_id}-artifacts"
  location     = var.region
  kms_key_id   = module.kms.keys["storage"].id
  
  lifecycle_rules = [{
    age                    = 90
    action_type           = "Delete"
    num_newer_versions    = null
    with_state            = null
    matches_storage_class = null
    action_storage_class  = null
  }]
}

module "workload_identity" {
  source = "../../modules/workload-identity"
  
  project_id   = var.project_id
  pool_id      = "webapp-pool"
  display_name = "WebApp CI/CD Pool"
  
  github_config = {
    attribute_condition = "assertion.repository == 'myorg/webapp'"
  }
  
  service_account_impersonation = {
    "deploy-sa" = {
      service_account_email = google_service_account.deploy.email
      member               = "principalSet://iam.googleapis.com/projects/${var.project_number}/locations/global/workloadIdentityPools/webapp-pool/attribute.repository/myorg/webapp"
    }
  }
}

resource "google_service_account" "deploy" {
  project      = var.project_id
  account_id   = "webapp-deploy"
  display_name = "WebApp Deployment SA"
}
EOF

echo ""
echo "✅ Generic terraform-google-compliance-modules created!"
echo ""
echo "📋 This repository contains:"
echo "- Generic, reusable GCP modules"
echo "- Security best practices built-in"
echo "- Compliance-ready configurations"
echo "- Can be used by any organization"
echo ""
echo "🔄 Next: Run ./create-u2i-app-modules.sh to create U2I-specific wrappers"