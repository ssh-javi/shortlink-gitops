#!/usr/bin/env bash
# =============================================================================
# forward.sh - abre port-forwards para el demo:
#
#   ArgoCD : http://localhost:8080   (admin / password del secret)
#   Web    : http://localhost:8081
#   Grafana: http://localhost:3000   (admin / admin)
#
# Ctrl+C para detenerlos todos.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_cmd kubectl

PID_FILE="/tmp/shortlink-forwards.pids"
# Limpia un fichero de PIDs obsoleto (forwards muertos por crash/reinicio)
if [[ -f "$PID_FILE" ]]; then
  read -r OLD_P1 OLD_P2 OLD_P3 < "$PID_FILE" 2>/dev/null || true
  if kill -0 "$OLD_P1" "$OLD_P2" "$OLD_P3" 2>/dev/null; then
    info "Ya hay forwards activos. Detenlos con: kill \$(cat $PID_FILE)"
    exit 0
  fi
  warn "Fichero de PIDs obsoleto (los forwards ya no están vivos). Limpiándolo..."
  rm -f "$PID_FILE"
fi

info "Abriendo port-forwards (3 pestañas para el demo)..."
kubectl -n argocd port-forward svc/argocd-server 8080:80 >/dev/null &
P1=$!
kubectl -n shortlink port-forward svc/shortlink-web 8081:80 >/dev/null &
P2=$!
# The observability app installs kube-prometheus-stack with ArgoCD's release
# name "observability", so the Grafana service is observability-grafana.
kubectl -n monitoring port-forward svc/observability-grafana 3000:80 >/dev/null &
P3=$!

echo "$P1 $P2 $P3" > "$PID_FILE"
trap 'kill $P1 $P2 $P3 2>/dev/null; rm -f "$PID_FILE"; ok "Forwards detenidos."' EXIT

ARGO_PASSWORD="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo '?')"

echo
echo "============================================================="
echo "  🖥️  ArgoCD  : http://localhost:8080   (admin / ${ARGO_PASSWORD:-?})"
echo "  🌐  Web     : http://localhost:8081"
echo "  📊  Grafana : http://localhost:3000   (admin / admin)"
echo "============================================================="
echo "  Pulsa Ctrl+C para detener los forwards."
wait
