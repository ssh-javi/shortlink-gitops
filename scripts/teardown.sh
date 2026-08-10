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
