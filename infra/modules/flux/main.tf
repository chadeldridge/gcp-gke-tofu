resource "github_repository" "flux" {
  name        = var.github_repo
  description = var.github_repo
  visibility  = "public"
}

# 3. Bootstrap Flux to the GitHub repository
resource "flux_bootstrap_git" "flux" {
  depends_on = [github_repository.flux]

  embedded_manifests = true
  path              = var.target_path
  namespace         = var.flux_namespace
}
