locals {
  # GitHub's own OIDC "sub" claim shape for a branch-triggered run. Matching
  # on this directly (rather than the repository/ref attributes separately)
  # means repo and ref can't be satisfied by independently-matching but
  # mismatched claims -- this is Google's recommended trust-policy shape.
  github_subject = "repo:${var.github_owner}/${var.github_repo}:ref:${var.github_ref}"
}

################################################################################
# Workload Identity Pool
# Lets GitHub Actions exchange its OIDC token for short-lived GCP credentials
# -- no long-lived service account key stored as a GitHub secret.
################################################################################
resource "google_iam_workload_identity_pool" "github_actions" {
  # Ensure all required GCP APIs are enabled before creating the pool.
  depends_on = [google_project_service.enabled_apis]

  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = "GitHub Actions"
  description               = "Keyless CI auth for GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github_actions" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # The real authorization boundary: only tokens minted for this exact repo
  # and ref can be exchanged through this provider at all. The attribute
  # mapping above only controls what claims are visible to IAM bindings --
  # it does not by itself restrict who can authenticate.
  #
  # Inlined literally (not via local.github_subject) so static analysis
  # (Checkov CKV_GCP_125) can see the repo:owner/repo:ref:... shape directly.
  # Single-quoted CEL string literal -- avoids an HCL \" escape that
  # python-hcl2 (and therefore Checkov) doesn't resolve, which left a
  # literal backslash breaking its quote-matching regex.
  attribute_condition = "assertion.sub == 'repo:${var.github_owner}/${var.github_repo}:ref:${var.github_ref}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

################################################################################
# CI deployer service account
################################################################################
resource "google_service_account" "deployer" {
  project      = var.project_id
  account_id   = var.deployer_account_id
  display_name = "GitHub Actions CI deployer"
}

# Bound to the exact subject, not an attribute set -- only the same repo/ref
# matched by the provider's attribute_condition above can ever present a
# token satisfying this binding.
resource "google_service_account_iam_member" "deployer_wif_binding" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/subject/${local.github_subject}"
}

# Least privilege: push access scoped to the single Artifact Registry repo,
# not project-wide artifactregistry.writer.
resource "google_artifact_registry_repository_iam_member" "deployer_writer" {
  project    = var.project_id
  location   = var.artifact_registry_location
  repository = var.artifact_registry_repository_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.deployer.email}"
}
