locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env_name = local.env_vars.locals.env

  #source_base_url = "github.com/<org>/<repo>/modules//gke"
  source_base_url = "../../../modules/app"
}

terraform {
  required_providers {
    github = {
      source = "integrations/github"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    kubectl = {
      source = "gavinbunney/kubectl"
    }
    flux = {
      source = "fluxcd/flux2"
    }
    tls = {
      source = "hashicorp/tls"
    }
  }

  #source = "${local.source_base_url}?ref=v0.1.0"
  source = "${local.source_base_url}"
}

dependency "gke" {
  config_path = "../gke"
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
  cluster_endpoint = dependency.gke.outputs.cluster_endpoint
}
