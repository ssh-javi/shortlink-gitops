#!/usr/bin/env bash
# =============================================================================
# teardown.sh - destruye el entorno local del demo (minikube + git daemon).
#
#   scripts/teardown.sh          # borra minikube y el git daemon
#   scripts/teardown.sh --local  # además borra los repos temporales de /tmp
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

[[ "${1:-}" == "--local" ]] && CLEAN_TMP=1 || CLEAN_TMP=0

info "Deteniendo git daemon (si existe)..."
pkill -f "git daemon" 2>/dev/null && ok "git daemon detenido" || info "no había git daemon"

# Respaldo de la clave de Sealed Secrets: si no la guardamos, al recrear el
# cluster el controller genera una clave nueva y los SealedSecrets del repo
# ya no se pueden descifrar. setup.sh la restaura automáticamente si existe.
SEALED_KEY_BACKUP="${SEALED_KEY_BACKUP:-$HOME/.shortlink/sealed-secrets-key.yaml}"
if kubectl -n kube-system get secret -l sealedsecrets.bitnami.com/sealed-secrets-key >/dev/null 2>&1; then
  mkdir -p "$(dirname "$SEALED_KEY_BACKUP")"
  kubectl -n kube-system get secret -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > "$SEALED_KEY_BACKUP"
  ok "Clave de Sealed Secrets respaldada en $SEALED_KEY_BACKUP"
fi

info "Eliminando cluster minikube..."
if minikube status >/dev/null 2>&1; then
  minikube delete --purge
  ok "Cluster eliminado"
else
  info "minikube ya estaba detenido"
fi

if [[ "$CLEAN_TMP" == "1" ]]; then
  rm -rf /tmp/shortlink-gitops-local /tmp/shortlink-gitops-local.git
  ok "Repos temporales eliminados"
fi

ok "Entorno limpiado."
