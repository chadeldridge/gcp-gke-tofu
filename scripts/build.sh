#!/usr/bin/env bash
# Build and push the uptest image, then pin the target environment's
# kustomization.yaml to the resulting digest.
#
# Trunk-based flow: every push to main builds one immutable image tagged
# with the git short SHA. The image is then referenced by digest (not tag)
# in the environment manifest, and Flux reconciles the change into the
# cluster. Higher environments are promoted forward by copying this same
# digest into their manifest (see scripts/promote.sh, once it exists) --
# never by rebuilding.
set -euo pipefail

# shellcheck source=scripts/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

ENV="${1:-dev}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

require gcloud docker git

if [ -f "${ROOT}/.env" ]; then
  # shellcheck disable=SC1091 # gitignored, user-supplied, no fixed content to follow
  source "${ROOT}/.env"
fi

: "${GOOGLE_PROJECT:?GOOGLE_PROJECT must be set (.env or environment)}"
: "${GOOGLE_REGION:?GOOGLE_REGION must be set (.env or environment)}"

IMAGE_TAG="$(git -C "${ROOT}" rev-parse --short HEAD)"

# GAR_ENDPOINT can be supplied directly (CI sets this as a repo variable to
# avoid needing terragrunt/state access just to read one output). Falls back
# to reading it live for local/manual runs.
if [ -z "${GAR_ENDPOINT:-}" ]; then
  phase_start "Looking up Artifact Registry endpoint..."
  GAR_ENDPOINT=$(cd "${ROOT}/infra/live/dev/artifact_registry" && terragrunt output -raw docker_repo_endpoint)
  phase_end
fi

GAR_IMAGE="${GAR_ENDPOINT}/uptest"

phase_start "Configuring Docker auth for ${GOOGLE_REGION}-docker.pkg.dev..."
timed 30 gcloud auth configure-docker "${GOOGLE_REGION}-docker.pkg.dev" --quiet
phase_end

phase_start "Building and pushing ${GAR_IMAGE}:${IMAGE_TAG}..."
run docker buildx build --push -t "${GAR_IMAGE}:${IMAGE_TAG}" "${ROOT}/apps/uptest"
phase_end

phase_start "Resolving pushed image digest..."
DIGEST=$(gcloud artifacts docker images describe "${GAR_IMAGE}:${IMAGE_TAG}" \
  --format='value(image_summary.digest)')
[[ -n "${DIGEST}" ]] || die "Could not resolve digest for ${GAR_IMAGE}:${IMAGE_TAG}"
dbg "DIGEST: ${DIGEST}"
echo "${GAR_IMAGE}@${DIGEST}" > "${ROOT}/.last-build-digest"
phase_end

# Pin the environment manifest to this digest (kustomize's images.digest
# field). This is what makes the deployed image immutable and satisfies
# Checkov's CKV_K8S_14/CKV_K8S_43 for real, instead of via a skip comment.
KUSTOMIZATION="${ROOT}/k8s/apps/${ENV}/uptest/kustomization.yaml"
phase_start "Pinning ${KUSTOMIZATION} to ${DIGEST}..."
python3 - "$KUSTOMIZATION" "$GAR_IMAGE" "$DIGEST" <<'PY'
import re
import sys

path, image, digest = sys.argv[1:4]
with open(path) as f:
    text = f.read()

text = re.sub(r"\n\s*newTag:.*", "", text)
if "digest:" in text:
    text = re.sub(r"digest:.*", f"digest: {digest}", text)
else:
    text = text.rstrip("\n") + f"\n    digest: {digest}\n"

with open(path, "w") as f:
    f.write(text)
PY
phase_end

if git -C "${ROOT}" diff --quiet "${KUSTOMIZATION}"; then
  log "  ${KUSTOMIZATION} unchanged — no commit needed"
else
  phase_start "Committing and pushing pinned manifest..."
  git -C "${ROOT}" add "${KUSTOMIZATION}"
  git -C "${ROOT}" commit -m "chore: deploy uptest ${IMAGE_TAG}"
  git -C "${ROOT}" push
  phase_end
fi
