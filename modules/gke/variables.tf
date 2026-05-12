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

variable "network_name" {
  type        = string
  description = "VPC network name"
}

variable "subnetwork_name" {
  type        = string
  description = "VPC subnetwork name"
}

variable "pods_range_name" {
  type        = string
  description = "Name of secondary range for pods"
}

variable "services_range_name" {
  type        = string
  description = "Name of secondary range for services"
}

variable "kubernetes_version" {
  type    = string
  default = "1.33"
}

variable "node_machine_type" {
  type    = string
  default = "e2-standard-4"
}

variable "node_count" {
  type    = number
  default = 3
}

variable "min_node_count" {
  type    = number
  default = 3
}

variable "max_node_count" {
  type    = number
  default = 10
}

variable "node_disk_size_gb" {
  type    = number
  default = 100
}

variable "node_zones" {
  type        = list(string)
  description = "Zones within the region where nodes are created. Controls the actual node count (node_count * len(node_zones) total nodes). Defaults to a single zone to avoid unexpected multiplication."
  default     = []
}