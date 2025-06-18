#!/bin/bash
# Script to create the production project for webapp team

set -e

echo "🚀 Creating production project for webapp team"
echo "============================================="

PROJECT_ID="u2i-tenant-webapp-prod"
PROJECT_NAME="WebApp Team Production"
FOLDER_ID="914995929705"
BILLING_ACCOUNT="01AA86-A09BB4-30E84E"

# Check if project already exists
if gcloud projects describe $PROJECT_ID >/dev/null 2>&1; then
    echo "✅ Project $PROJECT_ID already exists"
else
    echo "Creating new project: $PROJECT_ID"
    
    # Create the project
    gcloud projects create $PROJECT_ID \
        --name="$PROJECT_NAME" \
        --folder=$FOLDER_ID \
        --labels=environment=production,purpose=tenant-application,compliance=iso27001-soc2-gdpr,data_residency=eu,region=belgium,gdpr_compliant=true,tenant=webapp-team
    
    echo "✅ Project created successfully"
    
    # Link billing account
    echo "Linking billing account..."
    gcloud billing projects link $PROJECT_ID \
        --billing-account=$BILLING_ACCOUNT
    
    echo "✅ Billing account linked"
fi

# Enable essential APIs
echo "Enabling essential APIs..."
gcloud services enable cloudresourcemanager.googleapis.com \
    --project=$PROJECT_ID

gcloud services enable storage-api.googleapis.com \
    --project=$PROJECT_ID

gcloud services enable cloudkms.googleapis.com \
    --project=$PROJECT_ID

echo "✅ Essential APIs enabled"

# Create state bucket with CMEK
echo ""
echo "📦 Creating state bucket for production environments..."

# First, create a KMS keyring and key for the state bucket
echo "Creating KMS keyring and key..."
gcloud kms keyrings create webapp-prod-state-keyring \
    --location=europe-west1 \
    --project=$PROJECT_ID 2>/dev/null || echo "Keyring already exists"

gcloud kms keys create webapp-prod-state-key \
    --location=europe-west1 \
    --keyring=webapp-prod-state-keyring \
    --purpose=encryption \
    --rotation-period=90d \
    --project=$PROJECT_ID 2>/dev/null || echo "Key already exists"

# Get the GCS service account
GCS_SA=$(gcloud storage service-agent --project=$PROJECT_ID)

# Grant GCS service account access to the key
gcloud kms keys add-iam-policy-binding webapp-prod-state-key \
    --location=europe-west1 \
    --keyring=webapp-prod-state-keyring \
    --member="serviceAccount:$GCS_SA" \
    --role="roles/cloudkms.cryptoKeyEncrypterDecrypter" \
    --project=$PROJECT_ID

# Create the state bucket
BUCKET_NAME="${PROJECT_ID}-tfstate"
if gsutil ls -b gs://$BUCKET_NAME >/dev/null 2>&1; then
    echo "✅ State bucket gs://$BUCKET_NAME already exists"
else
    echo "Creating state bucket: gs://$BUCKET_NAME"
    
    # Create bucket with CMEK encryption
    gcloud storage buckets create gs://$BUCKET_NAME \
        --project=$PROJECT_ID \
        --location=europe-west1 \
        --uniform-bucket-level-access \
        --public-access-prevention \
        --default-encryption-key=projects/$PROJECT_ID/locations/europe-west1/keyRings/webapp-prod-state-keyring/cryptoKeys/webapp-prod-state-key
    
    # Enable versioning
    gcloud storage buckets update gs://$BUCKET_NAME --versioning
    
    echo "✅ State bucket created with CMEK encryption"
fi

echo ""
echo "✅ Production project setup complete!"
echo ""
echo "Project ID: $PROJECT_ID"
echo "State Bucket: gs://$BUCKET_NAME"
echo "KMS Key: projects/$PROJECT_ID/locations/europe-west1/keyRings/webapp-prod-state-keyring/cryptoKeys/webapp-prod-state-key"