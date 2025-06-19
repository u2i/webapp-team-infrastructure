# WebApp Team Infrastructure

This repository manages the infrastructure for the WebApp team using Terragrunt and Terraform.

## 🏗️ Repository Structure

```
webapp-team-infrastructure/
├── projects/
│   ├── non-prod/                    # Non-production GCP project
│   │   ├── main.tf                  # Project-level resources
│   │   ├── dns.tf                   # DNS zone for *.u2i.dev
│   │   └── environments/
│   │       ├── dev/                 # Development environment
│   │       ├── staging/             # Staging environment
│   │       └── qa/                  # QA environment
│   └── prod/                        # Production GCP project
│       ├── main.tf                  # Project-level resources
│       ├── dns.tf                   # DNS zone for *.u2i.com
│       └── environments/
│           ├── pre-prod/            # Pre-production environment
│           └── prod/                # Production environment
└── terragrunt.hcl                   # Root Terragrunt configuration
```

## 🔧 Architecture

### Project Separation

- **Non-prod project** (`u2i-tenant-webapp`): Contains dev, staging, and QA environments
- **Prod project** (`u2i-tenant-webapp-prod`): Contains pre-prod and prod environments

### DNS Strategy

- Non-prod uses `*.u2i.dev` domain
- Prod uses `*.u2i.com` domain

### Module Architecture

This repository uses a modular approach:
1. **Project-level resources**: Managed with plain Terraform in `projects/{project}/`
2. **Environment resources**: Managed with Terragrunt, using modules from `u2i-terraform-modules`

## 🚀 Deploying Infrastructure

### Project-level resources

Project-level resources (DNS zones, WIF pools, service accounts) are managed with plain Terraform:

```bash
# Non-prod project resources
cd projects/non-prod
terraform init
terraform plan
terraform apply

# Prod project resources
cd projects/prod
terraform init
terraform plan
terraform apply
```

### Environment-specific resources

Environment-specific resources are managed with Terragrunt:

```bash
# Deploy dev environment
cd projects/non-prod/environments/dev
terragrunt apply

# Deploy production environment
cd projects/prod/environments/prod
terragrunt apply
```

### Deploy all environments

```bash
# Deploy all non-prod environments
cd projects/non-prod/environments
terragrunt run-all apply

# Deploy all prod environments
cd projects/prod/environments
terragrunt run-all apply
```

## 💾 State Management

- **Non-prod state**: `gs://u2i-tenant-webapp-tfstate`
- **Prod state**: `gs://u2i-tenant-webapp-prod-tfstate`

Terragrunt automatically manages state paths based on the environment.

## 🔒 GitOps Workflow

### Infrastructure Changes Process
1. **Pull Request** → Terraform plan generated and validated
2. **Slack Approval** → Infrastructure team approval required for project-level changes
3. **Terraform Apply** → Changes applied with full audit trail
4. **Verification** → Post-apply health checks

### Approval Requirements
- **Non-destructive changes**: Auto-approved after 2 minutes
- **Destructive changes**: Manual Slack approval required
- **Emergency changes**: Force apply with enhanced audit logging

## 🔐 Security & Compliance

All deployments enforce U2I security standards:
- ✅ CMEK encryption with 90-day rotation
- ✅ EU-only data residency (europe-west1)
- ✅ Compliance labels for ISO 27001, SOC 2, GDPR
- ✅ Private GKE nodes
- ✅ Binary authorization for production
- ✅ Vulnerability scanning

## 📋 Environment Configuration

Each environment's `terragrunt.hcl` references the webapp-infrastructure module:

```hcl
terraform {
  source = "git::https://github.com/u2i/u2i-terraform-modules.git//modules/webapp-infrastructure?ref=main"
}

inputs = {
  environment = "dev"
  gke_node_count = 1
  # Environment-specific overrides
}
```

## 🆘 Support

- **Infrastructure Team**: `#infrastructure-approvals` Slack channel
- **Security Issues**: `security-team@u2i.com`
- **Compliance Questions**: `compliance@u2i.com`
- **Platform Support**: `platform-team@u2i.com`

## 📦 Dependencies

- Terraform >= 1.6
- Terragrunt >= 0.54
- Google Cloud SDK
- GitHub repository access