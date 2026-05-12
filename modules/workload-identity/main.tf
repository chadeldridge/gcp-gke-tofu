# Create the GCP IAM service account
resource "google_service_account" "workload" {
  account_id   = var.service_account_name
  display_name = "Workload Identity SA for ${var.service_account_name}"
  project      = var.project_id
}

# Grant IAM roles to GCP service account
resource "google_project_iam_member" "workload_roles" {
  for_each = toset(var.gcp_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.workload.email}"
}

# Allow Kubernetes service account to impersonate the GCP service account
resource "google_service_account_iam_binding" "workload_identity" {
  service_account_id = google_service_account.workload.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.workload_identity_pool}[${var.namespace}/${var.service_account_name}]"
  ]
}

# Create Kubernetes service account
resource "kubernetes_service_account_v1" "workload" {
  metadata {
    name      = var.service_account_name
    namespace = var.namespace

    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.workload.email
    }
  }
}