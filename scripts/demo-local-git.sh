#!/usr/bin/env bash
# =============================================================================
# demo-local-git.sh - permite que ArgoCD sincronice SIN GitHub.
#
# Crea una copia espejo del repo (sin placeholders) en /tmp, la sirve con
# `git daemon` y aplica el app-of-apps apuntando a git://<host>.
#
# Útil para grabar el demo sin depender de internet/GitHub.
# En el "mundo real" simplemente se apunta a tu repositorio de GitHub.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

REPO_NAME="shortlink-gitops-local"
LOCAL_DIR="/tmp/${REPO_NAME}"
BARE_DIR="/tmp/${REPO_NAME}.git"
GIT_DAEMON_PORT="${GIT_DAEMON_PORT:-9418}"

# --- Detectar IP del host alcanzable desde el cluster ------------------------
detect_host_ip() {
  local net gw
  net="$(docker inspect minikube --format '{{.HostConfig.NetworkMode}}' 2>/dev/null | sed 's/^container://')"
  if [[ -n "$net" && "$net" != "default" ]]; then
    gw="$(docker network inspect "$net" --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null || true)"
    if [[ -n "$gw" ]]; then echo "$gw"; return; fi
  fi
  echo "172.17.0.1"
}
HOST_IP="${HOST_IP:-$(detect_host_ip)}"
GIT_URL="git://${HOST_IP}:${GIT_DAEMON_PORT}/${REPO_NAME}.git"

# --- Garantizar que el repo de trabajo tenga un commit -----------------------
if ! git -C "$PROJECT_ROOT" rev-parse --verify HEAD >/dev/null 2>&1; then
  info "El proyecto aún no tiene commits; creando el commit inicial local..."
  git -C "$PROJECT_ROOT" init -q
  git -C "$PROJECT_ROOT" add -A
  git -C "$PROJECT_ROOT" -c user.email=devops@localhost -c user.name="DevOps Local" commit -qm "chore: snapshot inicial del proyecto"
fi

# --- Crear la copia espejo con URLs renderizadas -----------------------------
info "Creando copia local del repo en $LOCAL_DIR"
rm -rf "$LOCAL_DIR" "$BARE_DIR"
mkdir -p "$LOCAL_DIR"
git -C "$PROJECT_ROOT" archive HEAD | tar -x -C "$LOCAL_DIR"

info "Renderizando repoURL -> $GIT_URL"
sed -i \
  -e "s|https://github.com/ssh-javi/shortlink-gitops.git|${GIT_URL}|g" \
  -e "/- values.ci.yaml/d" \
  "$LOCAL_DIR"/deploy/argocd/apps/*.yaml 2>/dev/null || true

git -C "$LOCAL_DIR" init -q -b main
git -C "$LOCAL_DIR" add -A
git -C "$LOCAL_DIR" -c user.email=devops@localhost -c user.name="DevOps Local" commit -qm "snapshot para demo local"
git clone --bare -q "$LOCAL_DIR" "$BARE_DIR"

# --- Servir con git daemon ---------------------------------------------------
pkill -f "git daemon.*${GIT_DAEMON_PORT}" 2>/dev/null || true
git daemon \
  --base-path=/tmp \
  --export-all \
  --reuseaddr \
  --enable=upload-pack \
  --port="$GIT_DAEMON_PORT" \
  --detach
ok "git daemon corriendo en $GIT_URL"

# --- Aplicar el app-of-apps (raíz) desde la copia local ----------------------
info "Aplicando app-of-apps (raíz) apuntando al repo local"
kubectl apply -f "$LOCAL_DIR/deploy/argocd/apps/app-of-apps.yaml" >/dev/null
ok "Listo. ArgoCD sincronizará desde el repo local."
info "  Para limpiar: scripts/teardown.sh --local"
