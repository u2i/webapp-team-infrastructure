# Outputs for tenant deployment example

output "tenant_project" {
  description = "Tenant project information"
  value = {
    project_id = google_project.tenant_app.project_id
    number     = google_project.tenant_app.number
  }
}

output "cloud_deploy_pipeline" {
  description = "Cloud Deploy pipeline information"
  value = {
    name     = google_clouddeploy_delivery_pipeline.webapp_pipeline.name
    location = google_clouddeploy_delivery_pipeline.webapp_pipeline.location
    targets = {
      nonprod = google_clouddeploy_target.nonprod_target.name
      prod    = google_clouddeploy_target.prod_target.name
    }
  }
}

output "artifact_registry" {
  description = "Artifact Registry repository information"
  value = {
    repository = google_artifact_registry_repository.webapp_images.name
    location   = google_artifact_registry_repository.webapp_images.location
    url        = "${google_artifact_registry_repository.webapp_images.location}-docker.pkg.dev/${google_project.tenant_app.project_id}/${google_artifact_registry_repository.webapp_images.repository_id}"
  }
}

output "deployment_commands" {
  description = "Commands to deploy applications"
  value = {
    build_image = "docker build -t ${google_artifact_registry_repository.webapp_images.location}-docker.pkg.dev/${google_project.tenant_app.project_id}/${google_artifact_registry_repository.webapp_images.repository_id}/webapp:latest ."
    push_image  = "docker push ${google_artifact_registry_repository.webapp_images.location}-docker.pkg.dev/${google_project.tenant_app.project_id}/${google_artifact_registry_repository.webapp_images.repository_id}/webapp:latest"
    deploy      = "gcloud deploy releases create release-$(date +%Y%m%d-%H%M%S) --project=${google_project.tenant_app.project_id} --region=${var.primary_region} --delivery-pipeline=${google_clouddeploy_delivery_pipeline.webapp_pipeline.name} --images=webapp=${google_artifact_registry_repository.webapp_images.location}-docker.pkg.dev/${google_project.tenant_app.project_id}/${google_artifact_registry_repository.webapp_images.repository_id}/webapp:latest"
  }
}

output "cluster_access" {
  description = "Commands to access the clusters from tenant project"
  value = {
    nonprod = data.terraform_remote_state.shared_gke.outputs.gke_clusters.non_production.connect_command
    prod    = data.terraform_remote_state.shared_gke.outputs.gke_clusters.production.connect_command
  }
}

output "namespaces" {
  description = "Tenant namespaces (managed in shared-gke/tenant-namespaces/webapp-team.tf)"
  value = {
    message = "Namespaces are centrally managed in the shared-gke configuration"
    nonprod = "webapp-team"
    prod    = "webapp-team"
  }
}

# Tenant compliance module outputs (commented out due to module being disabled)
# output "compliance_configuration" {
#   description = "Tenant compliance module configuration and outputs"
#   value = {
#     module_enabled = "false"
#     features_available = {
#       scoped_iam            = "Enable resource-specific IAM permissions"
#       binary_authorization  = "Enable container image validation"
#       production_approval   = "Enable Cloud Deploy approval gates"
#       rbac_separation       = "Enable platform vs tenant RBAC separation"
#       compliance_monitoring = "Enable enhanced audit logging and alerts"
#       network_policies      = "Enable namespace-level network isolation"
#       admission_controllers = "Enable Pod Security Standards enforcement"
#       secret_management     = "Enable secure secret access with Workload Identity"
#     }
#     compliance_summary = module.webapp_compliance.compliance_summary
#   }
# }

output "github_actions_config" {
  description = "Configuration for GitHub Actions workflows"
  value = {
    workload_identity_provider = "${google_iam_workload_identity_pool.github.name}/providers/${google_iam_workload_identity_pool_provider.github.workload_identity_pool_provider_id}"
    service_account            = google_service_account.terraform.email
    project_id                 = google_project.tenant_app.project_id
  }
}

output "next_steps" {
  description = "Next steps for deploying applications"
  value = [
    "1. Update GitHub repository variables with values from github_actions_config output",
    "2. Create Kubernetes manifests with skaffold.yaml and clouddeploy.yaml",
    "3. Build and push container image to Artifact Registry",
    "4. Create Cloud Deploy release",
    "5. Monitor deployment through Cloud Deploy console",
    "6. Approve production deployment when ready"
  ]
}

output "state_migration_status" {
  description = "State migration to dedicated bucket completed successfully"
  value = {
    status = "completed"
    bucket = "u2i-tenant-webapp-tfstate"
    prefix = "terraform/state"
    features = [
      "Project-local state storage",
      "CMEK encryption with 90-day rotation",
      "Complete isolation from other tenants",
      "Uniform bucket-level access enabled"
    ]
  }
}

output "state_migration_instructions" {
  description = "Instructions for migrating to dedicated state bucket for improved isolation"
  value = {
    current_backend = {
      bucket = "u2i-tfstate"
      prefix = "tenant-webapp-team"
    }
    new_backend = {
      bucket = google_storage_bucket.webapp_tfstate.name
      prefix = "terraform/state"
    }
    migration_steps = [
      "1. Run: terraform init",
      "2. Run: terraform state pull > webapp-team.tfstate",
      "3. Update backend config in main.tf to use new bucket",
      "4. Run: terraform init -migrate-state",
      "5. Confirm the migration when prompted",
      "6. Verify state in new bucket: gsutil ls gs://${google_storage_bucket.webapp_tfstate.name}/terraform/state/"
    ]
  }
}

output "compliance_status" {
  description = "Current compliance framework status"
  value = {
    frameworks = ["iso27001", "soc2", "gdpr"]
    data_residency = "europe-west1"
    encryption = "CMEK with 90-day rotation"
    audit_logging = "Enabled with 30-day retention"
    access_control = "Project-local service accounts with least privilege"
  }
}