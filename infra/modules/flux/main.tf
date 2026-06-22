# Construct the KinD cluster.
resource "kind_cluster" "this" {
  name = "flux-e2e"
}

# Initialize the GitHub repository.
resource "github_repository" "this" {
  name        = var.github_repo
  description = var.github_repo
  visibility  = "private"
  # Flux boostrap will not work with a repository that has not been initialized.
  auto_init   = true
}

# Bootstrap Flux to the GitHub repository.
resource "flux_bootstrap_git" "this" {
  depends_on = [github_repository.this]
  embedded_manifest = true
  path = "k8s/clusters/${var.cluster_name}"
}
