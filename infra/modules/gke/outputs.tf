output "cluster_name" {
  value     = google_container_cluster.primary.name
  sensitive = false
}

output "cluster_endpoint" {
  value     = google_container_cluster.primary.endpoint
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive = true
}

output "workload_identity_pool" {
  value     = "${var.project_id}.svc.id.goog"
  sensitive = false
}

output "node_service_account_email" {
  value     = google_service_account.gke_nodes.email
  sensitive = false
}
