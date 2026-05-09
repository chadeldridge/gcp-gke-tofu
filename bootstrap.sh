#!/bin/bash

encrypted="false"
stage="${DEPLOY_ENV:-dev}"
project="${GOOGLE_PROJECT}"
region="${GOOGLE_REGION:-us-east1}"
# Prefix ${stage}/appName
prefix="${stage}"
bucket_suffix="-tofu-state"
vers=10

help() {
    echo "Usage: $0 [options]"
    echo
    echo "bootstrap expects certain environment variables to be set. Ensure"
    echo "these variables are set before running bootstrap."
    echo "        DEPLOY_ENV     - Environment name (Default: dev)"
    echo "    Needed for bootstrap and opentofu:"
    echo "        GOOGLE_PROJECT - REQUIED: GCP project ID"
    echo "        GOOGLE_REGION  - (Default: us-east1)"
    echo "        GOOGLE_ENCRYPTION_KEY - 32-byte AES base64 If you want CSEK encryption."
    echo
    echo "Options:"
    echo
    echo "  -h, --help      Show this help message and exit"
    echo "  --prefix=PATH   State file prefix path. Default: DEPLOY_ENV"
    echo "                  Example: prd/appName"
    echo "  --vers=NUM      Number of state versions to keep in the bucket."
    echo
    echo "bootstrap uses 'jq' to parse json. Ensure it is installed first."
    echo
}

OPTS=$(getopt -o h --long help,prefix:,vers: -n 'bootstrap' -- "$@")
if [ $? != 0 ]; then echo; help; exit 1; fi

eval set -- "$OPTS"
set -e

while true; do
    case "$1" in
        --) shift; break ;;
        --prefix) prefix=$2; shift 2 ;;
        --vers) vers=$2; shift 2 ;;
        --help|-h) help; exit 0 ;;
        *) help; exit 0 ;;
    esac
done

if [ -z "$project" ]; then
    echo "error: no project given. set GOOGLE_PROJECT or pass as first arg."
    exit 1
fi

if ! command -v tofu &> /dev/null; then
    echo "error: tofu command not found. please install one and try again."
    exit 1
fi

if ! command -v gcloud &> /dev/null; then
    echo "error: gcloud command not found. please install one and try again."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "error: jq command not found. please install one and try again."
    exit 1
fi

if [ ! -z "$GOOGLE_ENCRYPTION_KEY" ]; then
    encrypted="true"
fi

# Debug
#echo
#echo "project:   $project"
#echo "stage:     $stage"
#echo "region:    $region"
#echo "prefix:    $prefix"
#echo "encrypted: $encrypted"
#echo "versions:  $vers"

create_bucket() {
    echo "Creating new bucket..."

    # Create a tmp dir for writing temporary files.
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "${tmp_dir}"' EXIT
    
    # Create a tmp lifecycle config file.
    lc_file="${tmp_dir}/gcs-lifecycle.json"
    cat << EOF > $lc_file
{
  "rule": [
    {
      "action": {"type": "Delete"},
      "condition": {
        "numNewerVersions": ${vers},
        "isLive": false
      }
    }
  ]
}
EOF
    
    # Create the new state bucket.
    gcloud storage buckets create \
        gs://${project}${bucket_suffix} \
        --project=${project} \
        --location=${region} \
        --lifecycle-file=${lc_file}
    
    # gcloud crate command does not provide feedback so verify the bucket was created with describe.
    desc=$(gcloud storage buckets describe gs://${project}${bucket_suffix} --format=json)
    bucket=$(echo $desc | jq -r '.name')
    
    # Make sure we got a bucket name back.
    if [ -z "$bucket" ]; then
        echo "error: bucket name is empty"
        exit 1
    fi
    
    # Enable versioning.
    gcloud storage buckets update "gs://${bucket}" --versioning
    
    # TODO: This doesn't work. Might have to get-iam-policy, edit it, then set-iam-policy.
    # Enable auditing on storage buckets.
    #gcloud projects add-iam-audit-config ${project} \
    #  --service="storage.googleapis.com" \
    #  --log-type="DATA_READ" \
    #  --log-type="DATA_WRITE"

    desc=$(gcloud storage buckets describe gs://${project}${bucket_suffix} --format=json)
}

# Check to see if the bucket already exists. To do so we need describe to be
# able to fail without exiting the script.
set +e
desc=$(gcloud storage buckets describe gs://${project}${bucket_suffix} --format=json 2>&1)

if [ $? -ne 0 ]; then
    # If descibe failed then we need to create a bucket. create_bucket should update the value of
    # $desc so we can reduce how many times we need to run it.
    echo "Bucket does not exist..."
set -e
    create_bucket
fi

# Get details from describe.
#desc=$(gcloud storage buckets describe gs://${project}${bucket_suffix} --format=json)
bucket=$(echo $desc | jq -r '.name')
is_versioned=$(echo $desc | jq -r '.versioning')
version_retention=$(echo $desc | jq -r '.lifecycle_config.rule.[].condition.numNewerVersions')
url=$(echo $desc | jq -r '.storage_url')

set +e
# Init tofu with bucket and prefix information.
tofu init -backend-config="bucket=${bucket}" -backend-config="prefix=${prefix} -upgrade"

echo
echo "Bucket:     ${bucket}"
echo "Prefix:     ${prefix}"
echo "State Path: ${url}${prefix}"
echo "Versioned:  ${is_versioned}"
echo "Versions:   ${version_retention}"
echo "Encrypted:  ${encrypted}"