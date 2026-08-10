#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh - instala las herramientas que faltan, sin tocar el sistema
# (todo va a ~/.local/bin). No requiere sudo.
# =============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

info "=== Bootstrap del proyecto ShortLink GitOps ==="

# --- Requisitos base ---------------------------------------------------------
require_cmd docker
require_cmd kubectl
require_cmd git

# minikube
if ! command -v minikube >/dev/null 2>&1; then
  install_binary minikube "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64.tar.gz"
fi

# --- Helm (gestor de paquetes de Kubernetes) --------------------------------
if ! command -v helm >/dev/null 2>&1; then
  install_binary helm "https://get.helm.sh/helm-v3.15.4-linux-amd64.tar.gz"
fi

# --- ArgoCD CLI (opcional, para demos y troubleshooting) ---------------------
if ! command -v argocd >/dev/null 2>&1; then
  info "Instalando 'argocd' en $LOCAL_BIN ..."
  mkdir -p "$LOCAL_BIN"
  curl -fsSL "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64" -o "$LOCAL_BIN/argocd"
  chmod +x "$LOCAL_BIN/argocd"
  ok "'argocd' instalado en $LOCAL_BIN/argocd"
fi

# --- Kubeconform (valida manifiestos en CI local) ----------------------------
if ! command -v kubeconform >/dev/null 2>&1; then
  install_binary kubeconform "https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-linux-amd64.tar.gz"
fi

# --- Kustomize (genera el ConfigMap de dashboards) ---------------------------
if ! command -v kustomize >/dev/null 2>&1; then
  install_binary kustomize "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv5.4.3/kustomize_v5.4.3_linux_amd64.tar.gz"
fi

# --- Kubeseal (sella secretos para Sealed Secrets) ---------------------------
if ! command -v kubeseal >/dev/null 2>&1; then
  info "Instalando 'kubeseal' en $LOCAL_BIN ..."
  mkdir -p "$LOCAL_BIN"
  curl -fsSL "https://github.com/bitnami/sealed-secrets/releases/download/v0.38.4/kubeseal-0.38.4-linux-amd64.tar.gz" -o "$LOCAL_BIN/kubeseal.tgz"
  tar -xzf "$LOCAL_BIN/kubeseal.tgz" -C "$LOCAL_BIN" kubeseal
  rm -f "$LOCAL_BIN/kubeseal.tgz"
  chmod +x "$LOCAL_BIN/kubeseal"
  ok "'kubeseal' instalado en $LOCAL_BIN/kubeseal"
fi

# --- kubectl-argo-rollouts (ver progreso de canaries en el demo) -------------
if ! command -v kubectl-argo-rollouts >/dev/null 2>&1; then
  info "Instalando 'kubectl-argo-rollouts' en $LOCAL_BIN ..."
  mkdir -p "$LOCAL_BIN"
  curl -fsSL "https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64" -o "$LOCAL_BIN/kubectl-argo-rollouts"
  chmod +x "$LOCAL_BIN/kubectl-argo-rollouts"
  ok "'kubectl-argo-rollouts' instalado en $LOCAL_BIN/kubectl-argo-rollouts"
fi

# --- Estado final ------------------------------------------------------------
echo
ok "Bootstrap completado. Herramientas:"
for t in docker kubectl minikube helm argocd kubeconform kubeseal; do
  v="$($t version 2>/dev/null | head -1 || true)"
  printf "  %-12s %s\n" "$t" "$v"
done
