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

output "next_steps" {
  description = "Next steps for deploying applications"
  value = [
    "1. Create Kubernetes manifests with skaffold.yaml and clouddeploy.yaml",
    "2. Build and push container image to Artifact Registry",
    "3. Create Cloud Deploy release",
    "4. Monitor deployment through Cloud Deploy console",
    "5. Approve production deployment when ready"
  ]
}