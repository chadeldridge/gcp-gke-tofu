include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path   = "${get_terragrunt_dir()}/../../_env/ingress.hcl"
  expose = true
}

# Override the env terraform include with a specific version.
#terraform {
#  source = "${include.env.locals.source_base_url}?ref=v0.2.0"
#}

# Inputs merged from env.hcl:
# project_id
# region
# cluster_name
inputs = {
}
