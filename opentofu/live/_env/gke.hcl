locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env_name = local.env_vars.locals.env

  #source_base_url = "github.com/<org>/<repo>/modules//gke"
  source_base_url = "../../../modules/gke"
}

terraform {
  #source = "${local.source_base_url}?ref=v0.1.0"
  source = "${local.source_base_url}"
}

dependency "network" {
  config_path = "../network"
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
  network_name        = dependency.network.outputs.network_name
  subnetwork_name     = dependency.network.outputs.subnetwork_main
  pods_range_name     = dependency.network.outputs.subnetwork_pods_name
  services_range_name = dependency.network.outputs.subnetwork_services_name
}
