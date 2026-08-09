output "cluster_name" {
  value     = module.gke.cluster_name
  sensitive = false
}

output "cluster_endpoint" {
  value     = module.gke.cluster_endpoint
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = module.gke.cluster_ca_certificate
  sensitive = true
}

output "workload_identity_pool" {
  value     = module.gke.workload_identity_pool
  sensitive = false
}

output "node_service_account_email" {
  value     = module.gke.node_service_account_email
  sensitive = false
}
