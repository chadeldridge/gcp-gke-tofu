output "gcp_service_account_email" {
  value = google_service_account.workload.email
}

output "gcp_service_account_name" {
  value = kubernetes_service_account_v1.workload.metadata[0].name
}