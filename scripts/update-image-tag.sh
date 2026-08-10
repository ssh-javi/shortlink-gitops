#!/usr/bin/env bash
# =============================================================================
# update-image-tag.sh <tag>
#
# Actualiza el tag de las imágenes en values.ci.yaml. Lo usa el workflow de
# CI/CD ("promote") para llevar el hash de la imagen recién publicada al estado
# deseado en Git. ArgoCD detecta el cambio y hace el rollout.
#
#   scripts/update-image-tag.sh sha-9f3a1b2
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NEW_TAG="${1:?uso: scripts/update-image-tag.sh <tag>}"
FILE="${2:-$SCRIPT_DIR/../deploy/helm/charts/shortlink/values.ci.yaml}"

[[ -f "$FILE" ]] || { echo "No existe: $FILE" >&2; exit 1; }

sed -i -E "s|^([[:space:]]+tag:).*|\1 ${NEW_TAG}|" "$FILE"

echo "values.ci.yaml actualizado:"
grep -n "tag:" "$FILE" || true
