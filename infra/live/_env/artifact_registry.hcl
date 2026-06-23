locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env_name = local.env_vars.locals.env

  #source_base_url = "github.com/<org>/<repo>/modules//gke"
  source_base_url = "../../../modules/gar"
}

terraform {
  #source = "${local.source_base_url}?ref=v0.1.0"
  source = "${local.source_base_url}"
}

# Inputs merged from env.hcl:
# project_id
# region
inputs = {
  docker_repo_name = "docker-private"
}
