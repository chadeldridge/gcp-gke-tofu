locals {
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  environment = local.env_vars.locals.env
  app_name    = "app"
}

inputs = merge(
  local.env_vars.locals,
  {
    cluster_name = "${local.app_name}-${local.environment}"
    tags = {
      Environment = local.environment
      ManagedBy   = "Terragrunt"
    }
  }
)

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "google" {
  # Leave project blank to get from GOOGLE_PROJECT env var.
  # Otherwise set the GCP Project ID here.
  #project = ""
  project = "${local.env_vars.locals.project_id}"
  region  = "${local.env_vars.locals.region}"
}
EOF
}

remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket = "${local.env_vars.locals.project_id}-tofu-state"
    prefix = "${path_relative_to_include()}/terraform.tfstate"
  }
}
