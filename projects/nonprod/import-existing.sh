#!/bin/bash
set -e

echo "Importing existing resources into Terraform state..."

# Import service accounts
echo "Importing terraform service account..."
terragrunt import google_service_account.terraform projects/u2i-tenant-webapp/serviceAccounts/terraform@u2i-tenant-webapp.iam.gserviceaccount.com || true

echo "Importing cloud deploy service account..."
terragrunt import google_service_account.cloud_deploy_sa projects/u2i-tenant-webapp/serviceAccounts/cloud-deploy-sa@u2i-tenant-webapp.iam.gserviceaccount.com || true

# Import Workload Identity Pool
echo "Importing Workload Identity Pool..."
terragrunt import google_iam_workload_identity_pool.github projects/u2i-tenant-webapp/locations/global/workloadIdentityPools/webapp-github-pool || true

# Import KMS resources
echo "Importing KMS key ring..."
terragrunt import google_kms_key_ring.webapp_keyring projects/u2i-tenant-webapp/locations/europe-west1/keyRings/webapp-team-keyring || true

echo "Importing KMS crypto key..."
terragrunt import google_kms_crypto_key.webapp_tfstate_key projects/u2i-tenant-webapp/locations/europe-west1/keyRings/webapp-team-keyring/cryptoKeys/webapp-tfstate-key || true

# Import Artifact Registry
echo "Importing Artifact Registry repository..."
terragrunt import google_artifact_registry_repository.webapp_images projects/u2i-tenant-webapp/locations/europe-west1/repositories/webapp-images || true

# Import storage buckets
echo "Importing deployment artifacts bucket..."
terragrunt import google_storage_bucket.deployment_artifacts u2i-tenant-webapp-deploy-artifacts || true

echo "Importing tfstate bucket..."
terragrunt import google_storage_bucket.webapp_tfstate u2i-tenant-webapp-tfstate || true

# Import Cloud Deploy resources
echo "Importing Cloud Deploy pipeline..."
terragrunt import google_clouddeploy_delivery_pipeline.webapp_pipeline projects/u2i-tenant-webapp/locations/europe-west1/deliveryPipelines/webapp-delivery-pipeline || true

echo "Importing Cloud Deploy target..."
terragrunt import google_clouddeploy_target.nonprod_target projects/u2i-tenant-webapp/locations/europe-west1/targets/nonprod-gke || true

echo "All imports completed!"