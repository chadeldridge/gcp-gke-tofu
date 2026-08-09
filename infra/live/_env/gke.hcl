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

  mock_outputs = {
    network_name             = "mock-network-name"
    subnetwork_name          = "mock-subnetwork-name"
    subnetwork_pods_name     = "mock-subnetwork-pods-name"
    subnetwork_services_name = "mock-subnetwork-services-name"
    subnetwork_main_cidr     = "10.0.0.0/20"
  }

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
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
  network_name            = dependency.network.outputs.network_name
  subnetwork_name         = dependency.network.outputs.subnetwork_name
  pods_range_name         = dependency.network.outputs.subnetwork_pods_name
  services_range_name     = dependency.network.outputs.subnetwork_services_name
  authorized_network_cidr = dependency.network.outputs.subnetwork_main_cidr
}
