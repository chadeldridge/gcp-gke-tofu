# OpenTofu GKE Deployment with Terragrunt

This project automates the provisioning of GKE (Google Kubernetes Engine) clusters using OpenTofu and Terragrunt. It configures a regional or single-zone cluster, service accounts with minimal permissions, and GKE Workload Identity. State files are stored securely in a Google Cloud Storage (GCS) backend encrypted with a Customer-Managed Encryption Key (CSEK).

---

## Prerequisites

Ensure you have the following CLI tools installed:
* **OpenTofu** (v1.6+)
* **Terragrunt** (v0.50+)
* **gcloud CLI** (configured and authenticated to your GCP account)
* **jq** (for parsing JSON inside bootstrap scripts)
* **direnv** (strongly recommended for environment variable management)

---

## Setup Environment Variables

The project requires several environment variables for GCP authentication, backend configuration, and state encryption.

### Using `direnv` (Recommended)
`direnv` automatically loads and unloads environment variables when you enter or leave the project directories. 

1. Install `direnv` and hook it to your shell (refer to [direnv installation guide](https://direnv.net/)).
2. Create a `.envrc` file in the project root:
   ```bash
   export GOOGLE_PROJECT="your-gcp-project-id"
   export GOOGLE_REGION="us-central1"
   export TF_VAR_node_zones='["us-central1-f"]'
   
   # Impersonation configuration
   export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT="mapo-tofu@your-gcp-project-id.iam.gserviceaccount.com"
   export GOOGLE_BACKEND_IMPERSONATE_SERVICE_ACCOUNT="mapo-tofu@your-gcp-project-id.iam.gserviceaccount.com"

   # 32-byte base64 AES encryption key for GCS state encryption
   export GOOGLE_ENCRYPTION_KEY="your-32-byte-base64-aes-key"
   ```
   > **Note**: To generate a secure 32-byte encryption key, run:
   > ```bash
   > openssl rand -base64 32
   > ```
3. Run `direnv allow` in the terminal to authorize loading the variables.

---

## How to Get Started (First Clone)

When you first clone this repository:

1. **Configure Environment Variables**: Create your `.envrc` file and allow it using `direnv allow`.
2. **Bootstrap the GCS State Bucket**: Run the bootstrap script from the project root to provision the GCS bucket:
   ```bash
   ./bootstrap.sh
   ```
   * The script checks if the bucket `<project-id>-tofu-state` already exists.
   * If not, it creates the bucket in your configured region, enables versioning, and configures the lifecycle policy.
   * Since this is run outside the `live` directory, it will only provision the GCS bucket and skip Terragrunt/OpenTofu workspace initialization.

---

## Managing Environments

Environments are defined dynamically under the `opentofu/live/` directory structure:
```
opentofu/
└── live/
    ├── _env/
    ├── dev/
    │   ├── env.hcl
    │   ├── gke/
    │   └── network/
    └── stg/
        ├── env.hcl
        ├── gke/
        └── network/
```

### 1. Creating a New Environment (e.g., `prod`)

To add a new environment beyond `dev` or `stg`:

1. **Create the Environment Directory**:
   ```bash
   mkdir -p opentofu/live/prod
   ```
2. **Copy and Edit `env.hcl`**:
   Copy the `env.hcl` configuration from `dev` and customize the environment parameters (e.g., machine types, zones, max nodes):
   ```bash
   cp opentofu/live/dev/env.hcl opentofu/live/prod/env.hcl
   ```
   Update `env.hcl`:
   ```hcl
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
     max_node_count    = 10
     node_machine_type = "e2-standard-4"
   }
   ```
3. **Copy the Service Configurations**:
   Copy the GKE and network Terragrunt module directories:
   ```bash
   cp -r opentofu/live/dev/network opentofu/live/prod/network
   cp -r opentofu/live/dev/gke opentofu/live/prod/gke
   ```

### 2. Deploying/Initializing a Service Directory

To deploy a service (e.g., `network` first, then `gke`):

1. **Change directory** to the service:
   ```bash
   cd opentofu/live/prod/network
   ```
2. **Run the Bootstrap Script**:
   Executing the bootstrap script from within a service directory validates the remote state bucket and initializes the local Terragrunt workspace:
   ```bash
   ../../../../bootstrap.sh
   ```
   * Since it is run inside `live/<env>/<service>`, it automatically computes the state prefix and performs `terragrunt init -upgrade`.
3. **Deploy the Resources**:
   ```bash
   terragrunt plan -out=tfplan.out
   terragrunt apply tfplan.out
   ```

Repeat these steps for the `gke` directory.

### 3. Updating and Planning across Environments

For CI/CD or running plan across multiple directories, use Terragrunt's capability to target specific changes. For example:
```bash
# Run plan for all units under dev environment
terragrunt run --all plan --queue-include-units-reading _env/gke.hcl --working-dir dev

# Run plan for all units under stg environment
terragrunt run --all plan --queue-include-units-reading _env/gke.hcl --working-dir stg
```

---

## Variable Reference
* `root.hcl`: Defines the root remote state bucket and prefix schema.
  - `app_name`: Used to identify the GKE cluster resource names (`${app_name}-${env}`).
  - `cluster_name`: Automatically generated from `app_name` and `env`.
* `env.hcl`: Defines environment-level overrides (imported automatically by the root config).

---

## Service Account Permissions & Impersonation

OpenTofu relies on a Google service account (`mapo-tofu@<project-id>.iam.gserviceaccount.com`) to manage infrastructure.

### Check Service Account IAM Roles
```bash
gcloud projects get-iam-policy <project-id> \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:mapo-tofu@<project-id>.iam.gserviceaccount.com"
```

Expected Roles:
* `roles/editor`
* `roles/iam.serviceAccountAdmin`
* `roles/resourcemanager.projectIamAdmin`

### Grant Roles & Configure Impersonation
If roles or impersonation access are missing, run the following command blocks to configure them:

```bash
# Grant your user permission to impersonate the service account
gcloud iam service-accounts add-iam-policy-binding \
  mapo-tofu@<project-id>.iam.gserviceaccount.com \
  --member="user:<your-gcp-user-email>" \
  --role="roles/iam.serviceAccountTokenCreator"

# Grant project IAM admin rights
gcloud projects add-iam-policy-binding <project-id> \
  --member="serviceAccount:mapo-tofu@<project-id>.iam.gserviceaccount.com" \
  --role="roles/resourcemanager.projectIamAdmin"

# Grant Service Account Admin role
gcloud projects add-iam-policy-binding <project-id> \
  --member="serviceAccount:mapo-tofu@<project-id>.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountAdmin"
```

---

## Resources & Reference Materials
* [Terraform GKE & Workload Identity Module Guide](https://oneuptime.com/blog/post/2026-02-09-terraform-gke-module-workload-identity/view)
* [FluxCD and GKE Workload Identity Setup](https://oneuptime.com/blog/post/2026-03-06-set-up-flux-cd-google-gke-workload-identity/view)
* [Spacelift Guide on Terraform tfvars](https://spacelift.io/blog/terraform-tfvars)
