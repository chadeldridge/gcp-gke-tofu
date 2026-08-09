variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "pool_id" {
  type        = string
  description = "Workload Identity Pool ID"
  default     = "github-actions"
}

variable "github_owner" {
  type        = string
  description = "GitHub organization or user that owns the repository allowed to authenticate"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name (without owner) allowed to authenticate"
}

variable "github_ref" {
  type        = string
  description = "Git ref allowed to authenticate as the deployer service account"
  default     = "refs/heads/main"
}

variable "deployer_account_id" {
  type        = string
  description = "Account ID for the CI deployer service account"
  default     = "gha-deployer"
}

variable "artifact_registry_repository_id" {
  type        = string
  description = "Artifact Registry repository ID to grant the deployer push access to"
}

variable "artifact_registry_location" {
  type        = string
  description = "Location/region of the Artifact Registry repository"
}
