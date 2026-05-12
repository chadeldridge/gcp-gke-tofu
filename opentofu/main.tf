provider "google" {
  # Leave project blank to get from GOOGLE_PROJECT env var.
  # Otherwise set the GCP Project ID here.
  #project = ""
  project = var.project_id
  region  = var.region
}

# Set all variables for the gke module.
module "gke" {
  source = "./modules/gke"

  project_id          = var.project_id
  region              = var.region
  cluster_name        = var.cluster_name
  network_name        = google_compute_network.main.name
  subnetwork_name     = google_compute_subnetwork.main.name
  pods_range_name     = "pods"
  services_range_name = "services"
  kubernetes_version  = "1.33"
  #node_machine_type   = "e2-standard-4"
  node_machine_type   = "e2-standard-2"
  node_count          = 3
  min_node_count      = 3
  max_node_count      = 15
  node_zones          = var.node_zones
}

# Configure Kubernetes provider using GKE credentials
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${module.gke.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
}

# Create application namespace
resource "kubernetes_namespace_v1" "app" {
  metadata {
    name = "application"
  }
}

# Set Workload Identity for the application
module "app_workload_identity" {
  source = "./modules/workload-identity"

  project_id                = var.project_id
  cluster_name           = var.cluster_name
  namespace              = kubernetes_namespace_v1.app.metadata[0].name
  service_account_name   = "app-sa"
  workload_identity_pool = module.gke.workload_identity_pool

  gcp_roles = [
    "roles/storage.objectViewer",
    "roles/pubsub.publisher",
    "roles/secretmanager.secretAccessor",
  ]
}

# Set Workload Identity for a data pipeline
module "pipeline_workload_identity" {
  source = "./modules/workload-identity"

  project_id             = var.project_id
  cluster_name           = var.cluster_name
  namespace              = kubernetes_namespace_v1.app.metadata[0].name
  service_account_name   = "pipeline-sa"
  workload_identity_pool = module.gke.workload_identity_pool

  gcp_roles = [
    "roles/bigquery.dataEditor",
    "roles/storage.objectAdmin",
  ]
}