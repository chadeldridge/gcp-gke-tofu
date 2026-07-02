locals {
  # Taken from environment directory live/(dev|stg|prd)/network
  env = basename(get_terragrunt_dir())

  # Based on environment variables
  project_id = get_env("GOOGLE_PROJECT")
  region     = get_env("GOOGLE_REGION")
  # Set TF_VAR_node_zones as a JSON string in the environment variable
  # e.g., export TF_VAR_node_zones='["us-central1-a", "us-central1-b"]'
  node_zones = jsondecode(get_env("TF_VAR_node_zones", "[]"))

  # Set these per environment
  kubernetes_version = "1.33"
  # Must have total_cpu_count <= 8 to remain within the free tier.
  # e2-standard-2 * 4 = 8 vCPUs
  max_node_count    = 4
  node_machine_type = "e2-standard-2"
  #node_machine_type = "e2-micro"
}
