include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path   = "${get_terragrunt_dir()}/../../_env/wif.hcl"
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
#   github_owner
#   github_repo
# Inputs gotten from _env/wif.hcl
#   artifact_registry_repository_id
#   artifact_registry_location
inputs = {
}
