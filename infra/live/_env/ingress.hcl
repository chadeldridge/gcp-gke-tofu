locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env_name = local.env_vars.locals.env

  #source_base_url = "github.com/<org>/<repo>/modules//ingress"
  source_base_url = "../../../modules/ingress"
}

terraform {
  #source = "${local.source_base_url}?ref=v0.1.0"
  source = "${local.source_base_url}"
}

# Inputs merged from env.hcl:
# project_id
# region
# cluster_name
inputs = {
}
