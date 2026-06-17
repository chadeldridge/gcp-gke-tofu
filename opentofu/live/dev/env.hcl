locals {
  project_id = get_env("GOOGLE_PROJECT")
  region     = get_env("GOOGLE_REGION")
  env        = basename(get_terragrunt_dir())
  # GKE specific settings
  # Cluster
  kubernetes_version = "1.33"
  # node_zones       = ["us-east1-a", "us-east1-d"]
  node_zones = jsondecode(get_env("TF_VAR_node_zones", "[]"))
  # Nodes
  # Must have total_cpu_count <= 8 to remain within the free tier.
  # e2-standard-2 * 4 = 8 vCPUs
  max_node_count    = 4
  node_machine_type = "e2-standard-2"
}
