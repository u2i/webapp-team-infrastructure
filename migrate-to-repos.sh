#!/bin/bash
# Script to migrate to multi-repository structure

set -e

echo "🚀 Migrating to multi-repository structure"
echo "=========================================="

# Step 1: Create terraform-modules repository structure
echo "📦 Step 1: Preparing terraform-modules repository..."
mkdir -p ../terraform-modules/{modules,examples}

# Move the webapp-base module
echo "Moving webapp-base module..."
cp -r modules/webapp-base ../terraform-modules/modules/

# Create README for modules repo
cat > ../terraform-modules/README.md << 'EOF'
# Terraform Modules

This repository contains reusable Terraform modules for the organization.

## Available Modules

- `webapp-base` - Base infrastructure for web application teams
- `gke-cluster` - Standardized GKE cluster configuration
- `cloud-sql` - Cloud SQL with CMEK and compliance settings
- `vpc-network` - VPC network with security defaults

## Usage

```hcl
module "webapp" {
  source = "git::git@github.com:u2i/terraform-modules.git//modules/webapp-base?ref=v1.0.0"
  
  project_id  = "my-project"
  environment = "dev"
}
```

## Versioning

We use semantic versioning. See [releases](https://github.com/u2i/terraform-modules/releases) for available versions.
EOF

# Create example for webapp-base
mkdir -p ../terraform-modules/examples/webapp-base
cat > ../terraform-modules/examples/webapp-base/main.tf << 'EOF'
module "webapp_dev" {
  source = "../../modules/webapp-base"
  
  project_id               = "example-project"
  environment              = "dev"
  billing_account          = "01AA86-A09BB4-30E84E"
  enable_cloud_deploy      = true
  enable_artifact_registry = true
}

output "project_id" {
  value = module.webapp_dev.project_id
}
EOF

# Step 2: Update webapp-team-infrastructure
echo ""
echo "📦 Step 2: Updating webapp-team-infrastructure..."

# Update all terragrunt.hcl files to reference the modules repo
for env in dev staging qa prod pre-prod; do
  echo "Updating $env environment..."
  
  # For now, use local path (update to git URL after pushing)
  cat > environments/$env/terragrunt.hcl << EOF
# $env environment configuration

# Include root configuration
include "root" {
  path = find_in_parent_folders()
}

# Include environment variables
include "env" {
  path = "./env.hcl"
}

# Use the webapp-base module from terraform-modules repo
terraform {
  # After pushing to GitHub, update to:
  # source = "git::git@github.com:u2i/terraform-modules.git//modules/webapp-base?ref=v1.0.0"
  source = "../../../terraform-modules/modules/webapp-base"
}

# $env-specific inputs
inputs = {
  # Cloud Deploy and Artifact Registry enabled for $env
  enable_cloud_deploy      = $([ "$env" = "qa" ] && echo "false" || echo "true")
  enable_artifact_registry = true
  
  # Override any $env-specific values here
}
EOF
done

# Remove local modules directory
echo "Removing local modules directory..."
rm -rf modules/

# Step 3: Create .gitignore for terraform-modules
cat > ../terraform-modules/.gitignore << 'EOF'
# Terraform files
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
.terragrunt-cache/

# IDE files
.idea/
.vscode/
*.swp
*.swo

# OS files
.DS_Store
Thumbs.db

# Test files
*.tfplan
*.tfvars
!example.tfvars
EOF

# Copy .gitignore to this repo too
cp ../terraform-modules/.gitignore .

echo ""
echo "✅ Migration structure prepared!"
echo ""
echo "📋 Next steps:"
echo ""
echo "1. Initialize the terraform-modules repository:"
echo "   cd ../terraform-modules"
echo "   git init"
echo "   git add ."
echo "   git commit -m 'Initial commit: Shared Terraform modules'"
echo "   git remote add origin git@github.com:u2i/terraform-modules.git"
echo "   git push -u origin main"
echo "   git tag -a v1.0.0 -m 'Initial release'"
echo "   git push --tags"
echo ""
echo "2. Update webapp-team-infrastructure to use remote modules:"
echo "   - Edit each environments/*/terragrunt.hcl"
echo "   - Change source to: git::git@github.com:u2i/terraform-modules.git//modules/webapp-base?ref=v1.0.0"
echo ""
echo "3. Commit changes to webapp-team-infrastructure:"
echo "   git add ."
echo "   git commit -m 'Migrate to external terraform-modules repository'"
echo "   git push"
echo ""
echo "4. Set up GitHub repository settings:"
echo "   - terraform-modules: Allow only PR merges, require reviews"
echo "   - webapp-team-infrastructure: Protect main branch, require Slack approvals"