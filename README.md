# OpenTofu Bootstrap and GKE Deploy

## Resources
oneuptime.com and spacelift.io were both good resources.
[This](https://oneuptime.com/blog/post/2026-02-09-terraform-gke-module-workload-identity/view) article showing terraform using local modules to build a gke cluster with Workload Identity.

[This](https://oneuptime.com/blog/post/2026-03-06-set-up-flux-cd-google-gke-workload-identity/view) about using FluxCD and Terraform for GKE.

And [this](https://spacelift.io/blog/terraform-tfvars) article on tfvars files along with several other articles on spacelift.

## How To Use

### Pre-req
Set env variables for the following:

```bash
export GOOGLE_PROJECT="<project-id>"
export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT="mapo-tofu@<project-id>.iam.gserviceaccount.com"
# Following var sets the service account to use for the GCS backend.
export GOOGLE_BACKEND_IMPERSONATE_SERVICE_ACCOUNT="mapo-tofu@<project-id>.iam.gserviceaccount.com"
```

Recommend but not required:
```bash
export GOOGLE_REGION="us-east1"
export GOOGLE_ENCRYPTION_KEY="<32-byte base64 AES key>"
```

I use direnv in a higher level directory to automatically set the environment variables and keep them out of the repo.

> The encryption key is optional but recommended. One way to generate the encryption key:
> ```bash
> openssl rand -base64 32
> ```
> Make sure you save the key in a secure location. The key does not have to be unique across projects.

### 1: Create gcs bucket and init opentofu
Run `bootstrap.sh` to create the storage bucket and init opentofu. You can pass `--prefix=prd/exampleApp` to change the path where the opentofu state files will be kept. 

`bootstrap.sh` will not try to recreate teh bucket if it already exists so it can be ran to initialize an existing state on a new device.

### 2: Run tofu plan/apply
> You can check the current state with:
> ```bash
> tofu state list
> ```

Run your plan and apply actions as normal.

## Use .auto.tfvars
Use .auto.tfvars for setting the variables before depoloying.

```terraform
project_id   = "<project-id>"
region       = "us-east1"
cluster_name = "dev1-testapp"
# List multiple zones to have redundancy across zones in the region.
# node_zones = ["us-east1-a", "us-east1-d"]
# List a single zone to minimize footprint.
node_zones = ["us-east1-d"]
```

## Service Account Permissions and Impersonation

### Check IAM Roles of the Service Account.
```bash
gcloud projects get-iam-policy <project-id> --flatten="bindings[].members" \
    --format="table(bindings.role)" \
    --filter="bindings.members:mapo-tofu@<project-id>.iam.gserviceaccount.com"
```

Output:
```
ROLE
roles/editor
```

### Add missing Roles
```bash
# Grant your user permission to impersonate it.
gcloud iam service-accounts add-iam-policy-binding \
  mapo-tofu@<project-id>.iam.gserviceaccount.com \
  --member="user:<user-account>" \
  --role="roles/iam.serviceAccountTokenCreator"

# Grant IAM admin role so service account can set IAM policies.
gcloud projects add-iam-policy-binding <project-id> \
  --member="serviceAccount:mapo-tofu@<project-id>.iam.gserviceaccount.com" \
  --role="roles/resourcemanager.projectIamAdmin"

# Grant Service Account Admin role.
gcloud projects add-iam-policy-binding <project-id> \
  --member="serviceAccount:mapo-tofu@<project-id>.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountAdmin"
```

### Impersonate the Service Account
```bash
# Then set impersonation in your provider config or env var.
export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT=mapo-tofu@<project-id>.iam.gserviceaccount.com
```

### Verify the Service Account Roles
```bash
gcloud projects get-iam-policy <project-id> --flatten="bindings[].members" --format="table(bindings.role)" --filter="bindings.members:mapo-tofu@<project-id>.iam.gserviceaccount.com"
```

Output:
```
ROLE
roles/editor
roles/iam.serviceAccountAdmin
roles/resourcemanager.projectIamAdmin
```