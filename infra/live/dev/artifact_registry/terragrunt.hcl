include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path   = "${get_terragrunt_dir()}/../../_env/artifact_registry.hcl"
  expose = true
}

# Override the env terraform include with a specific version.
#terraform {
#  source = "${include.env.locals.source_base_url}?ref=v0.2.0"
#}

# Inputs merged from env.hcl:
#   project_id
#   region
#   env
inputs = {
  # region: The GCP region to deploy to. Default us-central1. Inlcuded in merged locals.
  #region = "us-central1"

  # docker_repo_name: The name to use when creating the new repository.
  #docker_repo_name = "docker-private"

  # Override here to deploy different apps from the same module.
  # untagged_keep_days: Number of days to keep untagged images before they are deleted.
  # Default 5 days.
  #untagged_keep_days = 7

  # versions_keep_count: Number of tagged versions to keep. Default 5.
  #versions_keep_count = 5
}
