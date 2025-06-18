# DNS configuration for webapp team

locals {
  dns_zone_name    = data.terraform_remote_state.organization.outputs.dns_zone_info.zone_name
  dns_zone_project = data.terraform_remote_state.organization.outputs.dns_zone_info.project_id
  root_domain      = trimsuffix(data.terraform_remote_state.organization.outputs.dns_zone_info.dns_name, ".")
}

# DNS record for the main webapp
resource "google_dns_record_set" "webapp" {
  project      = local.dns_zone_project
  managed_zone = local.dns_zone_name
  name         = "webapp.${local.root_domain}."
  type         = "A"
  ttl          = 300
  
  # This should come from the actual LoadBalancer service
  rrdatas = ["34.14.43.4"] # TODO: Reference from kubernetes_service data source
}

# DNS records for each environment
resource "google_dns_record_set" "environment_records" {
  for_each = toset(["dev", "staging", "qa", "pre-prod", "prod"])
  
  project      = local.dns_zone_project
  managed_zone = local.dns_zone_name
  name         = "${each.key}.webapp.${local.root_domain}."
  type         = "A"
  ttl          = 300
  
  # TODO: These should be dynamically set based on actual deployments
  rrdatas = each.key == "dev" ? ["34.14.43.4"] : ["35.241.5.173"] # Placeholder for non-dev
}

# CNAME for www subdomain
resource "google_dns_record_set" "www_webapp" {
  project      = local.dns_zone_project
  managed_zone = local.dns_zone_name
  name         = "www.webapp.${local.root_domain}."
  type         = "CNAME"
  ttl          = 300
  
  rrdatas = ["webapp.${local.root_domain}."]
}

# Outputs for other modules to use
output "dns_records" {
  description = "DNS records managed by this project"
  value = {
    webapp = google_dns_record_set.webapp.name
    environments = {
      for env, record in google_dns_record_set.environment_records : 
      env => record.name
    }
  }
}