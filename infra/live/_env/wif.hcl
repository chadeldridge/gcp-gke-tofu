locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env_name = local.env_vars.locals.env

  #source_base_url = "github.com/<org>/<repo>/modules/wif"
  source_base_url = "../../../modules/wif"
}

terraform {
  #source = "${local.source_base_url}?ref=v0.1.0"
  source = "${local.source_base_url}"
}

dependency "artifact_registry" {
  config_path = "../artifact_registry"

  mock_outputs = {
    docker_repo_name = "mock-docker-repo"
  }

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# Inputs merged from env.hcl:
# project_id
# region
# github_owner
# github_repo
inputs = {
  artifact_registry_repository_id = dependency.artifact_registry.outputs.docker_repo_name
  artifact_registry_location      = local.env_vars.locals.region
}
