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
  description = "Name of the VPC network to use for the cluster"
}

variable "subnetwork_name" {
  type        = string
  description = "Name of the subnetwork to use for the cluster"
}

variable "pods_range_name" {
  type        = string
  description = "Name of the subnetwork to use for pods"
}

variable "services_range_name" {
  type        = string
  description = "Name of the subnetwork to use for services"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version to use for the cluster"
  default     = "1.33"
}

variable "node_machine_type" {
  type        = string
  description = "Machine type for the nodes"
}

variable "node_count" {
  type        = number
  description = "Number of nodes to create in the cluster"
}

variable "min_node_count" {
  type        = number
  description = "Minimum number of nodes to create in the cluster"
}

variable "max_node_count" {
  type        = number
  description = "Maximum number of nodes to create in the cluster"
}

variable "node_zones" {
  type        = list(string)
  description = "Zones within the region where nodes are created. Controls the actual node count (node_count * len(node_zones) total nodes). Defaults to a single zone to avoid unexpected multiplication."
  default     = ["us-central1-a"]
}
