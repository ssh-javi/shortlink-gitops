#!/usr/bin/env bash
# =============================================================================
# common.sh - utilidades compartidas por los scripts del proyecto.
# =============================================================================
set -euo pipefail

# --- Colores ---------------------------------------------------------------
if [[ -t 1 ]]; then
  C_RESET='\033[0m'; C_RED='\033[0;31m'; C_GREEN='\033[0;32m'
  C_YELLOW='\033[0;33m'; C_BLUE='\033[0;34m'; C_BOLD='\033[1m'
else
  C_RESET=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_BOLD=''
fi

info()  { echo -e "${C_BLUE}[info]${C_RESET} $*"; }
ok()    { echo -e "${C_GREEN}[ok]${C_RESET} $*"; }
warn()  { echo -e "${C_YELLOW}[warn]${C_RESET} $*"; }
err()   { echo -e "${C_RED}[error]${C_RESET} $*" >&2; }

die() { err "$*"; exit 1; }

# --- Rutas ------------------------------------------------------------------
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- Herramientas instaladas localmente (bootstrap) --------------------------
LOCAL_BIN="${LOCAL_BIN:-$HOME/.local/bin}"
export PATH="$LOCAL_BIN:$PATH"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Falta '$1'. Ejecuta primero: scripts/bootstrap.sh"
}

# Descarga un binario a $LOCAL_BIN (Linux x86_64) de forma idempotente.
install_binary() {
  local name="$1" url="$2"
  if command -v "$name" >/dev/null 2>&1; then
    ok "'$name' ya está disponible ($(command -v "$name"))"
    return 0
  fi
  info "Instalando '$name' en $LOCAL_BIN ..."
  mkdir -p "$LOCAL_BIN"
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmp/pkg.tar.gz"
  tar -xzf "$tmp/pkg.tar.gz" -C "$tmp"
  # El binario puede estar en la raíz o en linux-amd64/
  local bin
  bin="$(find "$tmp" -type f -name "$name" | head -1)"
  [[ -n "$bin" ]] || die "No se encontró el binario '$name' en el paquete descargado"
  chmod +x "$bin"
  mv "$bin" "$LOCAL_BIN/$name"
  rm -rf "$tmp"
  ok "'$name' instalado en $LOCAL_BIN/$name"
}

# Espera hasta que un comando tenga éxito (timeout en segundos).
wait_for() {
  local desc="$1" timeout="${2:-180}" cmd="${3:-}"
  local elapsed=0
  info "Esperando: $desc (hasta ${timeout}s) ..."
  while ! eval "$cmd" >/dev/null 2>&1; do
    sleep 5
    elapsed=$((elapsed + 5))
    if [[ $elapsed -ge $timeout ]]; then
      die "Timeout esperando: $desc"
    fi
  done
  ok "$desc"
}

# Renders an ArgoCD Application manifest replacing the placeholder repo URL.
render_repo_url() {
  local file="$1" repo_url="$2" revision="${3:-main}"
  sed -e "s|https://github.com/ssh-javi/shortlink-gitops.git|${repo_url}|g" \
      -e "s|targetRevision: main|targetRevision: ${revision}|" \
      "$file"
}
