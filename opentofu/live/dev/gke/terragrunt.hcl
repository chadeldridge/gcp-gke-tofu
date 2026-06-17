include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path   = "${get_terragrunt_dir()}/../../_env/gke.hcl"
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
#   kubernetes_version
#   node_machine_type
#   max_node_count
#   node_zones
# Inputs gotten from _env/gke.hcl
#   cluster_name
#   network_name
#   subnetwork_name
#   pods_range_name
#   services_range_name
inputs = {
  node_count     = 3
  min_node_count = 3
}
