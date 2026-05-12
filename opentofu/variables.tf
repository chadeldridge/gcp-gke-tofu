variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  description = "GCP Region for the cluster"
  default     = "us-central1"
}

variable "cluster_name" {
  type        = string
  description = "GKE cluster name"
}

variable "node_zones" {
  type        = list(string)
  description = "Zones within the region where GKE nodes are placed. Pins node_count to these zones rather than all zones in the region."
  default     = []
}