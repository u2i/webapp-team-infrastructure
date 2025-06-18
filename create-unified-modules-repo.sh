#!/bin/bash
# Script to create unified terraform-modules repository

set -e

echo "🚀 Creating unified terraform-modules repository"
echo "=============================================="

# Create the unified structure
echo "📦 Creating unified module structure..."

mkdir -p ../terraform-modules/{modules/{organization,security,infrastructure,applications},examples,tests}

# Copy organization modules from gcp-org-compliance
echo "Copying organization modules..."
if [ -d "../gcp-org-compliance/modules" ]; then
  cp -r ../gcp-org-compliance/modules/* ../terraform-modules/modules/organization/ 2>/dev/null || true
fi

# Move webapp-base to applications
echo "Moving webapp-base to applications..."
cp -r modules/webapp-base ../terraform-modules/modules/applications/

# Create example security modules
echo "Creating security module examples..."

# KMS Encryption Module
mkdir -p ../terraform-modules/modules/security/kms-encryption
cat > ../terraform-modules/modules/security/kms-encryption/main.tf << 'EOF'
# KMS Encryption Module
# Provides CMEK encryption with organization standards

resource "google_kms_key_ring" "main" {
  project  = var.project_id
  name     = var.keyring_name
  location = var.location
}

resource "google_kms_crypto_key" "main" {
  name     = var.key_name
  key_ring = google_kms_key_ring.main.id
  purpose  = var.purpose

  rotation_period = var.rotation_period

  lifecycle {
    prevent_destroy = true
  }

  labels = merge(var.labels, {
    compliance = "cmek-required"
    managed_by = "terraform"
  })
}

# Grant GCS service account access if needed
resource "google_kms_crypto_key_iam_member" "gcs" {
  count = var.enable_gcs_encryption ? 1 : 0
  
  crypto_key_id = google_kms_crypto_key.main.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.project.number}@gs-project-accounts.iam.gserviceaccount.com"
}

data "google_project" "project" {
  project_id = var.project_id
}
EOF

cat > ../terraform-modules/modules/security/kms-encryption/variables.tf << 'EOF'
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "keyring_name" {
  description = "Name of the KMS keyring"
  type        = string
}

variable "key_name" {
  description = "Name of the KMS key"
  type        = string
}

variable "location" {
  description = "Location for the KMS resources"
  type        = string
  default     = "europe-west1"
}

variable "purpose" {
  description = "Purpose of the key"
  type        = string
  default     = "ENCRYPT_DECRYPT"
}

variable "rotation_period" {
  description = "Rotation period for the key"
  type        = string
  default     = "7776000s" # 90 days
}

variable "enable_gcs_encryption" {
  description = "Enable GCS bucket encryption with this key"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels to apply to the key"
  type        = map(string)
  default     = {}
}
EOF

cat > ../terraform-modules/modules/security/kms-encryption/outputs.tf << 'EOF'
output "keyring_id" {
  description = "The ID of the keyring"
  value       = google_kms_key_ring.main.id
}

output "key_id" {
  description = "The ID of the crypto key"
  value       = google_kms_crypto_key.main.id
}

output "key_name" {
  description = "The name of the crypto key"
  value       = google_kms_crypto_key.main.name
}
EOF

# Workload Identity Module
mkdir -p ../terraform-modules/modules/security/workload-identity
cat > ../terraform-modules/modules/security/workload-identity/main.tf << 'EOF'
# Workload Identity Module
# Standardized WIF setup for GitHub Actions

resource "google_iam_workload_identity_pool" "main" {
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = var.display_name
  description               = var.description
}

resource "google_iam_workload_identity_pool_provider" "github" {
  count = var.github_repo != null ? 1 : 0
  
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.main.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub Provider"
  
  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
  }
  
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
  
  attribute_condition = "assertion.repository == '${var.github_repo}'"
}

resource "google_service_account_iam_member" "workload_identity_user" {
  count = var.github_repo != null ? 1 : 0
  
  service_account_id = var.service_account_email
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.main.name}/attribute.repository/${var.github_repo}"
}
EOF

# Create comprehensive README
cat > ../terraform-modules/README.md << 'EOF'
# Terraform Modules

Unified repository for all Terraform modules used across the organization.

## Structure

```
modules/
├── organization/        # Organization-level resources
├── security/           # Security and compliance modules  
├── infrastructure/     # Core infrastructure components
└── applications/       # Application-specific modules
```

## Module Categories

### Organization Modules
- `folder-structure` - Organizational folder hierarchy
- `org-policies` - Organization policy constraints
- `audit-logging` - Centralized audit log configuration
- `billing-budgets` - Budget alerts and controls

### Security Modules
- `kms-encryption` - CMEK encryption setup
- `workload-identity` - Workload identity federation
- `vpc-service-controls` - VPC-SC perimeters
- `binary-authorization` - Binary authorization policies

### Infrastructure Modules
- `gke-cluster` - Standardized GKE clusters
- `vpc-network` - VPC networks with security defaults
- `cloud-sql` - Managed Cloud SQL instances

### Application Modules
- `webapp-base` - Base setup for web applications
- `data-platform` - Data analytics platform
- `ml-platform` - Machine learning infrastructure

## Usage

```hcl
module "encryption" {
  source = "git::git@github.com:u2i/terraform-modules.git//modules/security/kms-encryption?ref=v2.0.0"
  
  project_id   = "my-project"
  keyring_name = "app-keyring"
  key_name     = "app-key"
}
```

## Versioning

We use semantic versioning (MAJOR.MINOR.PATCH):
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes

## Testing

All modules must include:
1. Valid terraform configuration
2. Example usage in `examples/`
3. Automated tests in `tests/`
4. Documentation in README.md

## Contributing

1. Create feature branch
2. Add/update module
3. Add tests and examples
4. Submit PR with description
5. Await security team review for security/ modules
6. Await platform team review for organization/ modules

## Compliance

All modules must comply with:
- ISO 27001 requirements
- SOC 2 controls
- GDPR data residency
- Organization security policies
EOF

# Create CODEOWNERS file
cat > ../terraform-modules/CODEOWNERS << 'EOF'
# Default owners for everything
* @u2i/platform-team

# Organization modules require platform team review
/modules/organization/ @u2i/platform-team

# Security modules require security team review  
/modules/security/ @u2i/security-team @u2i/platform-team

# Infrastructure modules
/modules/infrastructure/ @u2i/platform-team

# Application modules - respective teams
/modules/applications/webapp-base/ @u2i/webapp-team @u2i/platform-team
/modules/applications/data-platform/ @u2i/data-team @u2i/platform-team
/modules/applications/ml-platform/ @u2i/ml-team @u2i/platform-team
EOF

# Create GitHub Actions workflow
mkdir -p ../terraform-modules/.github/workflows
cat > ../terraform-modules/.github/workflows/terraform-modules-ci.yml << 'EOF'
name: Terraform Modules CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  changed-modules:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
    steps:
      - uses: actions/checkout@v4
      - id: set-matrix
        run: |
          MODULES=$(find modules -type f -name "*.tf" -exec dirname {} \; | sort -u | jq -R -s -c 'split("\n")[:-1]')
          echo "matrix=${MODULES}" >> $GITHUB_OUTPUT

  validate:
    needs: changed-modules
    runs-on: ubuntu-latest
    strategy:
      matrix:
        module: ${{ fromJson(needs.changed-modules.outputs.matrix) }}
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        
      - name: Terraform Init
        run: terraform init
        working-directory: ${{ matrix.module }}
        
      - name: Terraform Validate
        run: terraform validate
        working-directory: ${{ matrix.module }}
        
      - name: Terraform Format Check
        run: terraform fmt -check -recursive
        working-directory: ${{ matrix.module }}

  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run tfsec
        uses: aquasecurity/tfsec-action@v1.0.0
        with:
          soft_fail: false
          
      - name: Run checkov
        uses: bridgecrewio/checkov-action@master
        with:
          directory: modules/
          framework: terraform

  release:
    needs: [validate, security-scan]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      
      - name: Bump version and push tag
        uses: anothrNick/github-tag-action@1.67.0
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          DEFAULT_BUMP: patch
          WITH_V: true
EOF

echo ""
echo "✅ Unified terraform-modules structure created!"
echo ""
echo "📋 Benefits of this approach:"
echo "- Single source of truth for all modules"
echo "- Security team can review and enforce standards"
echo "- Consistent versioning across the organization"
echo "- Easier dependency management between modules"
echo "- Centralized CI/CD and testing"
echo ""
echo "🔒 Security features:"
echo "- CODEOWNERS file ensures proper reviews"
echo "- Security scans on all PRs"
echo "- Automated versioning"
echo "- Compliance checks built-in"