output "workload_identity_provider" {
  description = "Full resource name to set as GCP_WORKLOAD_IDENTITY_PROVIDER in GitHub"
  value       = google_iam_workload_identity_pool_provider.github_actions.name
}

output "deployer_service_account_email" {
  description = "Email to set as GCP_CI_DEPLOYER_SA in GitHub"
  value       = google_service_account.deployer.email
}
