variable "project_id" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace for service account"
}

variable "service_account_name" {
  type        = string
  description = "Name for K8s and GCP service accounts"
}

variable "gcp_roles" {
  type        = list(string)
  description = "List of IAM roles to grant"
}

variable "workload_identity_pool" {
  type        = string
  description = "Workload Identity pool from GKE cluster"
}