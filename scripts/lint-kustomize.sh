#!/usr/bin/env bash
# Render every kustomization.yaml under k8s/ to catch broken resource
# references, invalid overlays, or bad patches before they reach Flux.
set -euo pipefail

# shellcheck source=scripts/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require kubectl

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

while IFS= read -r -d '' kfile; do
  dir=$(dirname "$kfile")
  rel="${dir#"${ROOT}"/}"
  if kubectl kustomize "$dir" >/dev/null; then
    dbg "OK: ${rel}"
  else
    echo "ERROR: kustomize build failed for ${rel}" >&2
    fail=1
  fi
done < <(find "${ROOT}/k8s" -name kustomization.yaml -print0)

exit "$fail"
