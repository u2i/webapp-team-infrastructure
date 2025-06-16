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
  description = "Tenant namespaces created in shared clusters"
  value = {
    nonprod = kubernetes_namespace.webapp_nonprod.metadata[0].name
    prod    = kubernetes_namespace.webapp_prod.metadata[0].name
  }
}

output "workload_identity" {
  description = "Workload Identity configuration for GitHub Actions"
  value = {
    provider                    = google_iam_workload_identity_pool_provider.github.name
    terraform_service_account   = google_service_account.terraform_webapp_team.email
    app_service_account        = google_service_account.github_actions_webapp_team.email
    pool_id                    = google_iam_workload_identity_pool.github_actions.workload_identity_pool_id
  }
}

output "github_secrets" {
  description = "GitHub secrets that need to be configured"
  value = {
    WORKLOAD_IDENTITY_PROVIDER = google_iam_workload_identity_pool_provider.github.name
    TERRAFORM_SERVICE_ACCOUNT  = google_service_account.terraform_webapp_team.email
    APP_SERVICE_ACCOUNT       = google_service_account.github_actions_webapp_team.email
    PROJECT_ID                = google_project.tenant_app.project_id
  }
}

output "pam_configuration" {
  description = "PAM entitlement configuration for infrastructure deployments"
  value = {
    entitlement_id         = google_privileged_access_manager_entitlement.tenant_infrastructure_deploy.entitlement_id
    entitlement_name       = google_privileged_access_manager_entitlement.tenant_infrastructure_deploy.name
    max_duration          = google_privileged_access_manager_entitlement.tenant_infrastructure_deploy.max_request_duration
    eligible_service_account = google_service_account.terraform_webapp_team.email
  }
}

output "next_steps" {
  description = "Next steps for deploying applications"
  value = [
    "1. Configure GitHub repository secrets with workload identity values",
    "2. Update GitHub Actions workflows to use tenant-specific service accounts", 
    "3. Create Kubernetes manifests with skaffold.yaml and clouddeploy.yaml",
    "4. Build and push container image to Artifact Registry",
    "5. Create Cloud Deploy release",
    "6. Monitor deployment through Cloud Deploy console",
    "7. Approve production deployment when ready"
  ]
}