resource "google_compute_global_address" "ingress_ip" {
  name    = "${var.cluster_name}-ingress-ip"
  project = var.project_id
}
