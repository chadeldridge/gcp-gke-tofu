# OpenTofu GKE Deployment with Terragrunt

This project provisions a GKE (Google Kubernetes Engine) cluster on GCP using OpenTofu and Terragrunt, then hands off application delivery to [Flux](https://fluxcd.io) for GitOps-based reconciliation. A sample app (`uptest`) is included to validate the cluster end-to-end, built and pinned by a trunk-based GitHub Actions workflow.

---

## Architecture

* **`infra/modules/`** — reusable OpenTofu modules: `network`, `gke`, `ingress`, `gar` (Artifact Registry), `wif` (Workload Identity Federation for CI), `workload-identity` (in-cluster Workload Identity bindings).
* **`infra/live/`** — Terragrunt live units that wire the modules together per environment. Only `dev` exists today; see [Adding a New Environment](#adding-a-new-environment).
* **`k8s/`** — Flux GitOps configuration: `clusters/<cluster>` is the entrypoint Flux reconciles, `apps/<cluster>` holds per-app manifests (kustomize), `infrastructure/` holds cluster-wide infra manifests. See `k8s/README.md`.
* **`apps/uptest`** — minimal Go app used to smoke-test a cluster/ingress after deployment.
* **`scripts/`** — bootstrap, deploy, and build tooling (see [Scripts](#scripts) below).
* **`.github/workflows/deploy-dev.yml`** — CI: builds and digest-pins the `uptest` image on every push to `main`.

---

## Prerequisites

Ensure you have the following CLI tools installed:
* **OpenTofu** (`tofu`)
* **Terragrunt**
* **gcloud CLI** (configured and authenticated to your GCP account)
* **kubectl**
* **docker** (for building app images)
* **flux CLI** (for bootstrapping GitOps)
* **jq** (for parsing JSON inside `scripts/bootstrap.sh`)
* **direnv** (optional, for environment variable management)

For local linting, `pre-commit` is used — see [Pre-commit Hooks](#pre-commit-hooks).

---

## Setup Environment Variables

The project reads configuration from environment variables at both the Terragrunt (`infra/live/dev/env.hcl`) and script (`scripts/*.sh`) layers. `scripts/deploy.sh` and `scripts/build.sh` will also source a gitignored `.env` file in the repo root if one exists — either approach (`.env` or `direnv`'s `.envrc`) works.

| Variable | Required by | Purpose |
|---|---|---|
| `GOOGLE_PROJECT` | scripts, `env.hcl` | Target GCP project ID |
| `GOOGLE_REGION` | scripts, `env.hcl` | Target GCP region |
| `TF_VAR_node_zones` | `env.hcl` | JSON array of zones for GKE nodes, e.g. `["us-central1-a"]` |
| `FLUX_GITHUB_OWNER` | `env.hcl`, `deploy.sh` | GitHub owner/org — also the only owner the `wif` module will let CI authenticate as |
| `FLUX_GITHUB_REPO` | `env.hcl`, `deploy.sh` | GitHub repo name — same constraint as above |
| `GITHUB_TOKEN` | `deploy.sh` (Flux bootstrap only) | Personal access token used by `flux bootstrap github` |
| `GOOGLE_IMPERSONATE_SERVICE_ACCOUNT` | optional | Service account to impersonate for `tofu`/`terragrunt` runs |
| `GOOGLE_BACKEND_IMPERSONATE_SERVICE_ACCOUNT` | optional | Service account to impersonate for GCS backend access |
| `GOOGLE_ENCRYPTION_KEY` | optional, `bootstrap.sh` | 32-byte base64 AES key, if you want CSEK on the state bucket |

### Using `direnv`
1. Install `direnv` and hook it to your shell ([installation guide](https://direnv.net/)).
2. Create a `.envrc` file in the project root with the variables above, e.g.:
   ```bash
   export GOOGLE_PROJECT="your-gcp-project-id"
   export GOOGLE_REGION="us-central1"
   export TF_VAR_node_zones='["us-central1-a"]'
   export FLUX_GITHUB_OWNER="your-github-user-or-org"
   export FLUX_GITHUB_REPO="gcp-gke-tofu"
   export GITHUB_TOKEN="ghp_..."
   ```
3. Run `direnv allow` to authorize loading the variables.

---

## How to Get Started (First Clone)

1. **Configure environment variables** as described above.
2. **Bootstrap the GCS state bucket**:
   ```bash
   ./scripts/bootstrap.sh
   ```
   * Creates the bucket `<project-id>-tofu-state` if it doesn't already exist, enables versioning, and sets a version-retention lifecycle policy.
   * Run from the repo root, this only provisions the state bucket. Run from inside a `infra/live/<env>/<service>` directory to also run `terragrunt init -upgrade` for that unit.
3. **Deploy everything**:
   ```bash
   ./scripts/deploy.sh dev
   ```
   This runs all three phases described below, then prints the cluster endpoint, ingress IP, and the GitHub repo secrets/variables needed to enable CI (`.github/workflows/deploy-dev.yml`).

---

## Scripts

* **`scripts/bootstrap.sh`** — provisions the Terraform/OpenTofu state bucket; optionally runs `terragrunt init` when run from a service directory.
* **`scripts/deploy.sh <env>`** — full environment deploy, in three phases:
  1. **Infrastructure**: `terragrunt plan`/`apply` for each service in order — `network`, `ingress`, `gke`, `artifact_registry`, `wif`.
  2. **App build** (skip with `--skip-build`): builds and pushes the `uptest` image, updates that environment's `kustomization.yaml`/`deployment.yaml`, and commits the change so Flux picks it up.
  3. **Flux bootstrap** (skip with `--skip-flux`): waits for cluster nodes to be `Ready`, then runs `flux bootstrap github` against `k8s/clusters/<env>`.
* **`scripts/build.sh <env>`** — CI-only build: builds and pushes the `uptest` image tagged with the git short SHA, resolves its digest, and pins that environment's `kustomization.yaml` to the digest (immutable deploys). Used by `.github/workflows/deploy-dev.yml`.
* **`scripts/common.sh`** — shared helpers (logging, `terragrunt output` lookups, tool checks) sourced by the other scripts.
* **`scripts/lint-kustomize.sh`** — renders every `kustomization.yaml` under `k8s/` via `kubectl kustomize` to catch broken references before Flux does; wired in as a local pre-commit hook.

---

## CI/CD: Trunk-Based Delivery

The repo follows trunk-based development for application delivery:

* Every push to `main` that touches `apps/uptest/**` triggers `.github/workflows/deploy-dev.yml`, which authenticates to GCP via Workload Identity Federation (no long-lived keys), builds one immutable image tagged with the git short SHA, resolves its digest, pins `k8s/apps/dev/uptest/kustomization.yaml` to that digest, and commits the pinned manifest back to `main`.
* Flux (already bootstrapped against `k8s/clusters/dev`) reconciles the pinned manifest into the dev cluster. The workflow never touches the cluster directly.
* Promoting an image to a higher environment (staging/prod, not yet added) is expected to copy the same digest into that environment's manifest rather than rebuilding.

CI authentication is provisioned by `infra/modules/wif` (`infra/live/dev/wif`). After applying that unit, `scripts/deploy.sh` prints the values to set as GitHub repo secrets/variables:
* `GCP_WORKLOAD_IDENTITY_PROVIDER` (secret)
* `GCP_CI_DEPLOYER_SA` (secret)
* `GAR_ENDPOINT` (variable)
* `GOOGLE_PROJECT` (variable)
* `GOOGLE_REGION` (variable)

---

## Pre-commit Hooks

This repo uses [pre-commit](https://pre-commit.com/) to validate Terraform/Terragrunt, shell, Docker, GitHub Actions, and Kubernetes changes before they're committed:

```bash
pip install pre-commit
pre-commit install
```

Configured hooks (`.pre-commit-config.yaml`): `terraform_fmt`, `terraform_docs`, `terraform_validate` (scoped to `infra/modules/`), `terragrunt_fmt`, `terragrunt_validate` (scoped to `infra/live/`), `terraform_checkov`, `shellcheck`, `hadolint`, `actionlint`, plus a local `kustomize-build` hook. Run all of them on demand with:

```bash
pre-commit run --all-files
```

---

## Adding a New Environment

To add an environment beyond `dev` (e.g. `staging`):

1. **Create the environment directory and copy `env.hcl`**:
   ```bash
   mkdir -p infra/live/staging
   cp infra/live/dev/env.hcl infra/live/staging/env.hcl
   ```
   Edit `env.hcl` to adjust per-environment values (`kubernetes_version`, `max_node_count`, `node_machine_type`, etc.) — `env` and `project_id`/`region` are derived automatically from the directory name and environment variables.
2. **Copy the service directories**:
   ```bash
   cp -r infra/live/dev/network infra/live/staging/network
   cp -r infra/live/dev/ingress infra/live/staging/ingress
   cp -r infra/live/dev/gke infra/live/staging/gke
   cp -r infra/live/dev/artifact_registry infra/live/staging/artifact_registry
   cp -r infra/live/dev/wif infra/live/staging/wif
   ```
   Remove any `.terraform.lock.hcl`/`.terragrunt-cache` copied along with them — each unit regenerates its own on `init`.
3. **Add matching `k8s/clusters/staging` and `k8s/apps/staging` directories** so Flux has something to reconcile once the cluster exists.
4. **Deploy**:
   ```bash
   ./scripts/deploy.sh staging
   ```

---

## Variable Reference

* **`infra/root.hcl`** — root Terragrunt config: generates the `google` provider block, configures the GCS remote state backend (`<project-id>-tofu-state`, prefixed by unit path), and merges `env.hcl` locals plus `cluster_name`/`tags` into every unit's inputs.
* **`infra/live/_env/*.hcl`** — per-service input definitions (`network.hcl`, `gke.hcl`, `ingress.hcl`, `artifact_registry.hcl`, `wif.hcl`), included by each environment's matching service directory.
* **`infra/live/<env>/env.hcl`** — environment-level overrides (project, region, GitHub owner/repo, node sizing).

---

## Resources & Reference Materials
* [Terraform GKE & Workload Identity Module Guide](https://oneuptime.com/blog/post/2026-02-09-terraform-gke-module-workload-identity/view)
* [FluxCD and GKE Workload Identity Setup](https://oneuptime.com/blog/post/2026-03-06-set-up-flux-cd-google-gke-workload-identity/view)
* [Spacelift Guide on Terraform tfvars](https://spacelift.io/blog/terraform-tfvars)
