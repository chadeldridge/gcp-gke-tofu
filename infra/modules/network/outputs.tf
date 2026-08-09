output "network_name" {
  value = google_compute_network.main.name
}

output "subnetwork_name" {
  value = google_compute_subnetwork.main.name
}

output "subnetwork_pods_name" {
  value = google_compute_subnetwork.main.secondary_ip_range[0].range_name
}

output "subnetwork_services_name" {
  value = google_compute_subnetwork.main.secondary_ip_range[1].range_name
}

output "subnetwork_main_cidr" {
  value = google_compute_subnetwork.main.ip_cidr_range
}

##### Below outputs are currently unused #####
output "subnetwork_pods_cidr" {
  value = google_compute_subnetwork.main.secondary_ip_range[0].ip_cidr_range
}

output "subnetwork_services_cidr" {
  value = google_compute_subnetwork.main.secondary_ip_range[1].ip_cidr_range
}

output "network_router" {
  value = google_compute_router.main.name
}

output "network_router_nat" {
  value = google_compute_router_nat.main.name
}
