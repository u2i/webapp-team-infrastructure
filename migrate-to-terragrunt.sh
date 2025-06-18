#!/bin/bash
# Migration script from Terraform to Terragrunt

set -e

echo "🔄 Migrating webapp-team-infrastructure to Terragrunt structure"
echo "=================================================="

# Check if we're in the right directory
if [ ! -f "main.tf" ]; then
    echo "❌ Error: main.tf not found. Run this script from the repository root."
    exit 1
fi

# Create backup
echo "📦 Creating backup of current state..."
mkdir -p backups/$(date +%Y%m%d_%H%M%S)
cp -r *.tf *.tfvars backups/$(date +%Y%m%d_%H%M%S)/ 2>/dev/null || true

# Move current Terraform files to a temporary location
echo "🚚 Moving current Terraform files..."
mkdir -p temp_tf_files
mv *.tf temp_tf_files/ 2>/dev/null || true
mv *.tfvars temp_tf_files/ 2>/dev/null || true

# Archive the old files
echo "📁 Archiving original Terraform files..."
mkdir -p legacy
mv temp_tf_files/* legacy/ 2>/dev/null || true
rmdir temp_tf_files

echo "✅ Migration structure created!"
echo ""
echo "📋 Next steps:"
echo "1. Update the billing_account in terragrunt.hcl"
echo "2. Create the production project (u2i-tenant-webapp-prod) if it doesn't exist"
echo "3. Create state buckets for each project:"
echo "   - gs://u2i-tenant-webapp-tfstate (for dev/staging/qa)"
echo "   - gs://u2i-tenant-webapp-prod-tfstate (for prod/pre-prod)"
echo ""
echo "4. Test with dev environment first:"
echo "   cd environments/dev"
echo "   terragrunt init"
echo "   terragrunt plan"
echo ""
echo "5. Import existing resources (if any):"
echo "   terragrunt import google_project.tenant_app u2i-tenant-webapp"
echo ""
echo "6. Update GitHub Actions workflows to use Terragrunt"
echo ""
echo "Original Terraform files have been moved to: ./legacy/"