locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env_name = local.env_vars.locals.env

  source_base_url = "../../../modules/flux"
}

terraform {
  source = "${local.source_base_url}"
}

dependency "gke" {
  config_path = "../gke"
}

# Why did gemini add this?
#dependency "gke" {
#  config_path = "../gke"
#
#  mock_outputs = {
#    cluster_endpoint       = "127.0.0.1"
#    cluster_ca_certificate = "bW9jay1jYS1jZXJ0aWZpY2F0ZQ=="
#    cluster_name           = "mock-cluster"
#  }
#  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
#}

generate "providers" {
  path      = "providers.tf"
  if_exists = "overwrite"
  contents  = <<EOF
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
      source = "fluxcd/flux"
    }
  }
}

data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${dependency.gke.outputs.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode("${dependency.gke.outputs.cluster_ca_certificate}")
}

provider "github" {
  token = var.github_token
  owner = var.github_owner
}

provider "flux" {
  kubernetes = {
    host                   = "https://${dependency.gke.outputs.cluster_endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode("${dependency.gke.outputs.cluster_ca_certificate}")
  }
  git = {
    url = "https://github.com/$${var.github_owner}/$${var.github_repo}.git"
    http = {
      username    = var.github_owner
      password    = var.github_token
    }
    branch = var.github_branch
  }
}
EOF
}

# Inputs merged from env.hcl:
# project_id
# region
inputs = {
  github_owner = get_env("TF_VAR_github_owner")
  github_token = get_env("TF_VAR_github_token")
  target_path  = "k8s/clusters/${local.env_name}"
}
