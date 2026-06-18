locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env_name = local.env_vars.locals.env

  #source_base_url = "github.com/<org>/<repo>/modules//network"
  source_base_url = "../../../modules/network"
}

terraform {
  #source = "${local.source_base_url}?ref=v0.1.0"
  source = "${local.source_base_url}"
}

# Inputs merged from env.hcl:
# project_id
# region
# cluster_name
# kubernetes_version
# node_machine_type
# max_node_count
# node_zones
inputs = {
}
