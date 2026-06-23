output "docker_repo_id" {
  description = "The name of the Artifact Registry repository"
  value = google_artifact_registry_repository.docker_repo.name
}

output "docker_repo_name" {
  description = "The name of the Artifact Registry repository"
  value = google_artifact_registry_repository.docker_repo.name
}

output "docker_repo_endpoint" {
  description = "The Docker pull endpoint for the repository"
  value       = format("%s-docker.pkg.dev/%s/%s", google_artifact_registry_repository.docker_repo.location, google_artifact_registry_repository.docker_repo.project, google_artifact_registry_repository.docker_repo.repository_id)
}
