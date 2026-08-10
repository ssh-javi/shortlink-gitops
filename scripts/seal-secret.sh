#!/usr/bin/env bash
# =============================================================================
# seal-secret.sh - regenera el SealedSecret de la app con la clave del cluster
# actual.
#
#   scripts/seal-secret.sh              # re-sella con los valores por defecto
#   POSTGRES_PASSWORD=miclave scripts/seal-secret.sh
#
# ¿Cuándo usarlo?
#   - Cluster nuevo / máquina nueva: el SealedSecret commiteado está cifrado
#     con la clave del cluster donde se generó. Si no tienes el respaldo de la
#     clave (~/.shortlink/sealed-secrets-key.yaml), el controller nuevo no
#     puede descifrarlo y la API no arranca. Re-sella con este script.
#   - Rotar la password de PostgreSQL.
#
# Requisitos: kubeseal instalado (scripts/bootstrap.sh) y cluster levantado.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."

TARGET="${1:-$PROJECT_ROOT/deploy/helm/charts/shortlink/templates/sealedsecret.yaml}"
PW="${POSTGRES_PASSWORD:-shortlink}"
NS="${SHORTLINK_NAMESPACE:-shortlink}"
DB_HOST="${SHORTLINK_DB_HOST:-shortlink-postgres}"

require_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Falta '$1'" >&2; exit 1; }; }
require_cmd kubectl
require_cmd kubeseal

info() { echo -e "\033[0;34m[info]\033[0m $*"; }
ok()   { echo -e "\033[0;32m[ok]\033[0m $*"; }

# 1. Build the plain Secret in-memory (dry-run, never touches the cluster)
SECRET_YAML=$(kubectl create secret generic shortlink-secret -n "$NS" \
  --from-literal="DATABASE_URL=postgres://shortlink:${PW}@${DB_HOST}:5432/shortlink" \
  --from-literal="REDIS_URL=redis://shortlink-redis:6379" \
  --from-literal="POSTGRES_PASSWORD=${PW}" \
  --dry-run=client -o yaml)

# 2. Seal with the current cluster's controller key (namespace-wide scope)
info "Sellando con la clave del controller actual..."
SEALED=$(printf '%s' "$SECRET_YAML" | kubeseal \
  --controller-name sealed-secrets --controller-namespace kube-system \
  --format yaml --scope namespace-wide)

# 3. Extract just the spec.encryptedData block and rebuild the chart template
#    (the metadata name stays templated, the namespace is fixed to shortlink
#    because the encrypted blob is namespace-bound).
ENCRYPTED=$(printf '%s' "$SEALED" | awk '
  /^  encryptedData:/{f=1}
  f && !/^  template:/{print}
  f && /^  template:/{exit}
')
[[ -n "$ENCRYPTED" ]] || die "No se pudo extraer encryptedData del output de kubeseal"

cat > "$TARGET" <<EOF
# SealedSecret (bitnami.com/v1alpha1) - safe to commit in Git.
# The controller in the cluster unseals it into the regular Secret
# "shortlink-secret" that the API + PostgreSQL reference.
#
# Re-seal (new cluster without the key backup, or rotated DB password):
#   scripts/seal-secret.sh
#
# Manual equivalent:
#   kubectl create secret generic shortlink-secret -n shortlink \\
#     --from-literal=DATABASE_URL=postgres://shortlink:<pw>@shortlink-postgres:5432/shortlink \\
#     --from-literal=REDIS_URL=redis://shortlink-redis:6379 \\
#     --from-literal=POSTGRES_PASSWORD=<pw> --dry-run=client -o yaml \\
#   | kubeseal --controller-name sealed-secrets --controller-namespace kube-system \\
#       --format yaml --scope namespace-wide > sealedsecret.yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: {{ include "shortlink.fullname" . }}-secret
  namespace: shortlink
  annotations:
    sealedsecrets.bitnami.com/namespace-wide: "true"
spec:
${ENCRYPTED}
  template:
    metadata:
      annotations:
        sealedsecrets.bitnami.com/namespace-wide: "true"
      name: {{ include "shortlink.fullname" . }}-secret
      namespace: shortlink
    type: Opaque
EOF

ok "SealedSecret regenerado en $TARGET"
echo
echo "  Commit y push para que ArgoCD lo aplique:"
echo "    git add $TARGET && git commit -m 'chore(secrets): re-seal' && git push"
