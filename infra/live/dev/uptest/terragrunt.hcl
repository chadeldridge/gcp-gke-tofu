include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path   = "${get_terragrunt_dir()}/../../_env/uptest.hcl"
  expose = true
}

inputs = {
  # region: The GCP region to deploy to. Default us-central1. Inlcuded in merged locals.
  #region = "us-central1"

  # app_name: The name of the application to deploy.
  app_name = "uptest"

  # Override here to deploy different apps from the same module.
  # untagged_keep_days: Number of days to keep untagged images before they are deleted.
  # Default 5 days.
  #untagged_keep_days = 7

  # versions_keep_count: Number of tagged versions to keep. Default 5.
  #versions_keep_count = 5

  # cluster_endpoint: The endpoint of the GKE cluster to deploy to. Set in _env/uptest.hcl.
  #cluster_endpoint = dependency.gke.outputs.cluster_endpoint

  # github_owner: The owner of the GitHub repository to deploy to. Get from env variables.
  #github_owner = ""

  # github_token: The token to use for GitHub authentication. Get from env variables.
  #github_token = ""

  # github_repo: The name of the GitHub repository to deploy to. Get from env variables.
  github_repo = "gcp-gke-tofu"

  # github_branch: Set this to use a branch besides main.
  #github_branch       = "dev"
}
