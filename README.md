# WebApp Team Infrastructure

This repository manages the infrastructure for the WebApp team using Terragrunt and Terraform.

## 🏗️ Repository Structure

```
webapp-team-infrastructure/
├── projects/
│   ├── non-prod/                    # Non-production GCP project
│   │   └── terragrunt.hcl          # Infrastructure for dev/qa/staging
│   └── prod/                        # Production GCP project
│       └── terragrunt.hcl          # Infrastructure for pre-prod/prod
├── clouddeploy.yaml                 # Cloud Deploy pipeline configuration
└── terragrunt.hcl                   # Root Terragrunt configuration
```

## 🔧 Architecture

### Project Separation

- **Non-prod project** (`u2i-tenant-webapp`): Hosts dev, qa, and staging environments
- **Prod project** (`u2i-tenant-webapp-prod`): Hosts pre-prod and prod environments

### Infrastructure vs Application

This repository manages **project-level infrastructure**:
- GKE clusters (one per project)
- VPC networking
- DNS zones
- Artifact Registry
- Cloud Deploy pipeline
- Service accounts & IAM
- Project-level monitoring/logging

**Environment-specific configuration** is managed in the application repository (`webapp-team-app`) through:
- Kubernetes manifests (k8s/overlays/)
- Ingress configurations
- SSL certificates
- ConfigMaps
- Environment variables

### DNS Strategy

- Non-prod uses `*.u2i.dev` domain
- Prod uses `*.u2i.com` domain

## 🚀 Deploying Infrastructure

### Non-prod Infrastructure

```bash
cd projects/non-prod
terragrunt init
terragrunt plan
terragrunt apply
```

### Production Infrastructure

```bash
cd projects/prod
terragrunt init
terragrunt plan
terragrunt apply
```

## 📦 Application Deployment

Application deployments to specific environments (dev, qa, staging, pre-prod, prod) are handled by:
1. **Cloud Deploy** - Manages the deployment pipeline
2. **GitHub Actions** - Triggers deployments on commits
3. **Kubernetes manifests** - Define environment-specific configurations

See the [webapp-team-app](https://github.com/u2i/webapp-team-app) repository for application deployment details.

## 💾 State Management

- **Non-prod state**: `gs://u2i-tenant-webapp-tfstate`
- **Prod state**: `gs://u2i-tenant-webapp-prod-tfstate`

## 🔒 GitOps Workflow

### Infrastructure Changes Process
1. **Pull Request** → Terraform plan generated and validated
2. **Approval** → Required for infrastructure changes
3. **Terraform Apply** → Changes applied with full audit trail
4. **Verification** → Post-apply health checks

## 🔐 Security & Compliance

All deployments enforce U2I security standards:
- ✅ CMEK encryption with 90-day rotation
- ✅ EU-only data residency (europe-west1)
- ✅ Compliance labels for ISO 27001, SOC 2, GDPR
- ✅ Private GKE nodes for production
- ✅ Binary authorization for production
- ✅ Vulnerability scanning

## 🆘 Support

- **Infrastructure Team**: `#infrastructure-approvals` Slack channel
- **Security Issues**: `security-team@u2i.com`
- **Compliance Questions**: `compliance@u2i.com`
- **Platform Support**: `platform-team@u2i.com`

## 📋 Dependencies

- Terraform >= 1.6
- Terragrunt >= 0.54
- Google Cloud SDK
- GitHub repository access