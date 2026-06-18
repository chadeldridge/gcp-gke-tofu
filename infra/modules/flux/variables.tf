# Cluster Variables
variable "project_id" {
  type = string
  description = "Project ID for the cluster"
}

variable "region" {
  type = string
  description = "Region where the cluster is located"
}

variable "cluster_name" {
  type = string
  description = "Cluster name"
}

variable "use_private_endpoint" {
  type = bool
  description = "Connect to the cluster using a private endpoint"
  default = false
}

variable "flux_namespace" {
  type = string
  description = "Namespace for Flux"
  default = "flux-system"
}

# Repository Variables
variable "github_repo" {
  type = string
  description = "Name of the repository to use for Flux"
}

variable "github_token" {
  type = string
  description = "GitHub token for Flux"
}

variable "github_owner" {
  type = string
  description = "GitHub owner for Flux"
}

variable "github_branch" {
  type = string
  description = "GitHub branch for Flux"
  default = "main"
}

variable "target_path" {
  type = string
  description = "Relative path to the Git repository root where the sync manifest is commited."
}

variable "github_deploy_key_title" {
  type = string
  description = "Name of the GitHub deploy key"
}
