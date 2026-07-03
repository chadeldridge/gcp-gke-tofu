#!/usr/bin/env bash
# Deploy the GKE cluster in the specified environment
# Phases:
#   1. Deploy infrastructure (Terraform)
#   2. Build and push app Docker images
#   3. Deploy Flux
#
# Flux will automatically deploy the app docker images.

# ── helpers ──────────────────────────────────────────────────────────────────

log()  { echo "==> $*"; }
dbg()  { [[ "$DEBUG" == "true" ]] && echo "    [dbg] $*" >&2 || true; }
die()  { echo "ERROR: $*" >&2; exit 1; }
# Get an output value from terragrunt.
tg_get() { terragrunt output -raw "$1"; }

help() {
    echo "Usage: $0 [options] <environment>"
    echo
    echo "Examples:"
    echo "  $0 dev"
    echo "  $0 prod --skip-build"
    echo
    echo "Options:"
    echo "  --debug        Enable debug mode"
    echo "  --help         Show this help message"
    echo "  --skip-build   Skip building Docker images"
    echo "  --skip-flux    Skip deploying Flux"
    echo "  --skip-infra   Skip deploying infrastructure"
}

# Print and run a command (command visible only in debug mode).
run() {
  dbg "$ $*"
  "$@"
}

# Run a command with a hard timeout (first arg = seconds).
# Prints the timeout and command in debug mode, always errors clearly on timeout.
timed() {
  local secs="$1"; shift
  dbg "$ (timeout ${secs}s) $*"
  local code=0
  # Capture exit code via || to avoid the `if ! cmd` bash gotcha where $?
  # inside an if-negation block reflects the inverted status (always 0).
  timeout "${secs}" "$@" || code=$?
  # exit code 124 is the timeout sentinel from GNU timeout
  [[ $code -eq 124 ]] && die "Command timed out after ${secs}s: $*"
  return $code
}

require() {
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || die "'$cmd' is not installed or not on PATH"
  done
}

# Track wall-clock time for each named phase.
_PHASE_T0=""
phase_start() {
  log "$*"
  _PHASE_T0=$(date +%s)
}
phase_end() {
  local elapsed=$(( $(date +%s) - _PHASE_T0 ))
  dbg "Phase completed in ${elapsed}s"
}

wait_for_ssh() {
    local user="$1" ip="$2"
    log "  Waiting for SSH at ${ip}..."

    [[ -f "${SSH_KEY}" ]] || die "SSH private key not found: ${SSH_KEY}
    Set SSH_PRIVATE_KEY in .env, or ensure ~/.ssh/id_kwi_ed25519 exists.
    Also verify 'sshPublicKey' is set in Pulumi config:
        pulumi config set gcp-k8s:sshPublicKey \"\$(cat ${SSH_KEY}.pub)\" --stack ${STACK}"

    local attempts=0 last_err=""
    until last_err=$(ssh \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=5 \
        -o BatchMode=yes \
        -o IdentitiesOnly=yes \
        -i "${SSH_KEY}" \
        "${user}@${ip}" true 2>&1); do
    attempts=$((attempts + 1))
    dbg "  Attempt ${attempts}/60 — ${last_err}"
    if [[ "$attempts" -ge 60 ]]; then
        die "SSH unavailable at ${user}@${ip} after $((attempts * 5))s.
  Last error: ${last_err}
  Common causes:
    - sshPublicKey not set in Pulumi config (run pulumi up again after setting it)
    - Wrong ansible_user / sshUser — current value: ${user}
    - VM still booting (try re-running with --skip-pulumi)"
        fi
        sleep 5
    done
    log "  SSH ready at ${ip}"
}

# ── setup ────────────────────────────────────────────────────────────────────

OPTS=$(getopt -o dhv --long debug,help,skip-build,skip-flux -n 'deploy' -- "$@")
if [ $? != 0 ]; then echo; help; exit 1; fi

eval set -- "$OPTS"

ENV=""
DEBUG=false
SKIP_BUILD=false
SKIP_FLUX=false

set -e

while true; do
    case "$1" in
        --)            shift; break ;;
        --debug|-d|-v) DEBUG=true; shift ;;
        --help|-h)     help; exit ;;
        --skip-build)  SKIP_BUILD=true; shift ;;
        --skip-flux)   SKIP_FLUX=true; shift  ;;
        *)             echo "option unknown: $1"; help; exit 1 ;;
    esac
done

# Set environment to the first argument if an argument is provided
if [ -n "$1" ]; then
    ENV=$1
    shift
fi

dbg "ENV: $ENV"

if [ -z "$ENV" ]; then
    echo "no environment argument provided"
    help
    exit 1
fi

#set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIVE_PATH="infra/live"
ENV_DIR="${ROOT}/${LIVE_PATH}/${ENV}"

# ── environment ────────────────────────────────────────────────────────

if [ -f "${ROOT}/.env" ]; then
    source "${ROOT}/.env"
    dbg "Loaded .env (project=${GOOGLE_PROJECT}, region=${GOOGLE_REGION})"
fi

# ── pre-flight checks ────────────────────────────────────────────────────────

phase_start "Checking required tools..."
require gcloud terragrunt kubectl

if ! $SKIP_BUILD; then
    echo "checking required tools for build..."
    require docker
fi

if ! $SKIP_FLUX; then
    echo "checking required tools for flux..."
    require flux
    [[ -n "${GITHUB_TOKEN:-}" ]]      || die "GITHUB_TOKEN must be set to bootstrap Flux"
    [[ -n "${FLUX_GITHUB_OWNER:-}" ]] || die "FLUX_GITHUB_OWNER must be set"
    [[ -n "${FLUX_GITHUB_REPO:-}" ]]  || die "FLUX_GITHUB_REPO must be set"
fi

# Default tag is the short git commit SHA so each build produces a unique, traceable tag.
# Override with UPTEST_TAG=<value> if a specific tag is needed.
GIT_SHA="$(git -C "${ROOT}" rev-parse --short HEAD 2>/dev/null)"
if [[ -z "${GIT_SHA}" ]] && [[ -z "${UPTEST_TAG:-}" ]]; then
  log "WARNING: git SHA unavailable at ${ROOT}; using timestamp as image tag"
fi
IMAGE_TAG="${UPTEST_TAG:-${GIT_SHA:-$(date +%s)}}"

dbg "ENV: ${ENV_DIR}"
dbg "FLUX_GITHUB_OWNER: ${FLUX_GITHUB_OWNER}"
dbg "FLUX_GITHUB_REPO: ${FLUX_GITHUB_REPO}"
phase_end

# ── phase 1: deploy infrastructure ───────────────────────────────────────────

deploy_infra() {
    local infra_dir=$1
    echo "Deploying infrastructure for ${ENV}..."

    SERVICES=("network" "ingress" "gke" "artifact_registry")
    for service in "${SERVICES[@]}"; do
        echo "    Deploying $service..."
        cd "${infra_dir}/${service}"
        terragrunt plan -out=tfplan.out
        terragrunt apply -auto-approve tfplan.out

        if [ "${service}" == "gke" ]; then
            CLUSTER_NAME=$(tg_get cluster_name)
            dbg "CLUSTER_NAME: ${CLUSTER_NAME}"
            # Get cluster credentials
            gcloud container clusters get-credentials "${CLUSTER_NAME}" \
                --region "${GOOGLE_REGION}" \
                --project "${GOOGLE_PROJECT}"
            CLUSTER_ENDPOINT=$(tg_get cluster_endpoint)
        fi

        if [ "${service}" == "ingress" ]; then
            INGRESS_IP=$(tg_get ingress_ip_address)
            dbg "INGRESS_IP: ${INGRESS_IP}"
        fi

        if [ "${service}" == "artifact_registry" ]; then
            GAR_REPO=$(tg_get "docker_repo_name")
            GAR_ENDPOINT=$(tg_get "docker_repo_endpoint")
            GAR_IMAGE="${GAR_ENDPOINT}/uptest"
            dbg "GAR_ENDPOINT: ${GAR_ENDPOINT}"
            dbg "GAR_IMAGE: ${GAR_IMAGE}:${IMAGE_TAG}"
        fi
    done
}

deploy_infra "${ENV_DIR}"

# ── phase 2: build & push app images ─────────────────────────────────────────

build_app() {
    local env=$1
    phase_start "Ensuring Artifact Registry repository '${GAR_REPO}' exists..."
    if timed 30 gcloud artifacts repositories describe "${GAR_REPO}" \
          --location="${GOOGLE_REGION}" \
          --project="${GOOGLE_PROJECT}" >/dev/null 2>&1; then
        dbg "Repository '${GAR_REPO}' already exists — skipping creation"
    else
        die "Repository '${GAR_REPO}' not found."
    fi
    phase_end

    phase_start "Configuring Docker auth for ${GOOGLE_REGION}-docker.pkg.dev..."
    timed 30 gcloud auth configure-docker "${GOOGLE_REGION}-docker.pkg.dev" --quiet
    phase_end

    phase_start "Building uptest image (${GAR_IMAGE}:${IMAGE_TAG})..."
    run docker buildx build --load -t "${GAR_IMAGE}:${IMAGE_TAG}" "${ROOT}/apps/uptest"
    phase_end

    phase_start "Pushing uptest image..."
    run docker push "${GAR_IMAGE}:${IMAGE_TAG}"
    phase_end

    # Update the kustomization manifest so Flux detects the change and redeploys.
    KUSTOMIZATION="${ROOT}/k8s/apps/${env}/uptest/kustomization.yaml"
    phase_start "Updating kustomization image tag to ${IMAGE_TAG}..."
    # Use a temp file + mv to avoid in-place sed portability issues.
    sed "s|newTag:.*|newTag: ${IMAGE_TAG}|" "${KUSTOMIZATION}" > "${KUSTOMIZATION}.tmp"
    mv "${KUSTOMIZATION}.tmp" "${KUSTOMIZATION}"
    phase_end

    if git -C "${ROOT}" diff --quiet "${KUSTOMIZATION}"; then
        log "  kustomization.yaml unchanged — no commit needed"
    else
        phase_start "Committing and pushing updated kustomization.yaml..."
        git -C "${ROOT}" add "${KUSTOMIZATION}"
        git -C "${ROOT}" commit -m "chore: deploy uptest ${IMAGE_TAG}"
        git -C "${ROOT}" push
        phase_end
    fi
}

if ! $SKIP_BUILD; then
    build_app "${ENV}"
fi

# ── phase 3a: deploy flux ─────────────────────────────────────────────────────

if ! $SKIP_FLUX; then
    phase_start "Waiting for all nodes to be Ready (needed before Flux bootstrap)..."
    timed 300 kubectl \
        wait --for=condition=Ready nodes --all --timeout=5m
    phase_end
fi

# ── phase 3b: deploy flux ─────────────────────────────────────────────────────

deploy_flux() {
    local env=$1
    phase_start "Bootstrapping Flux (owner=${FLUX_GITHUB_OWNER}, repo=${FLUX_GITHUB_REPO})..."
    run flux bootstrap github \
      --owner="${FLUX_GITHUB_OWNER}" \
      --repository="${FLUX_GITHUB_REPO}" \
      --branch=main \
      --path="k8s/clusters/${env}" \
      --personal \
      --token-auth \
      --timeout=15m
    phase_end
}

if ! $SKIP_FLUX; then
    deploy_flux "${ENV}"
fi

# ── done ─────────────────────────────────────────────────────────────────────

echo
echo "Cluster is ready."
echo "    Check uptest status: kubectl get pods -n uptest"
echo
echo "    uptest: http://${INGRESS_IP}"
echo "    (GCLB provisioning can take several minutes after the Ingress is first created;"
echo "     check progress with: kubectl get ingress -n uptest)"
