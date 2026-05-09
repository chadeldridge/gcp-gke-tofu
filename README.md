# OpenTofu Bootstrap and GKE Deploy

## How To Use

### Pre-req
Set env variables for the following:

```bash
export GOOGLE_PROJECT="my-project-id-982741"
export GOOGLE_APPLICATION_CREDENTIALS="/home/user1/path/to/gcp_service-key.json"
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
