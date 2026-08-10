#!/usr/bin/env bash
# =============================================================================
# setup.sh - levanta TODO el entorno con un solo comando:
#
#   scripts/setup.sh              # modo GitHub (ArgoCD sincroniza desde tu repo)
#   scripts/setup.sh --local      # modo 100% offline (git daemon local)
#
# Qué hace:
#   1. Verifica herramientas (bootstrap) y arranca minikube
#   2. Construye las imágenes de la app y las carga en el cluster
#   3. Instala ArgoCD (Helm) y el stack de observabilidad
#   4. Aplica el AppProject + app-of-apps para que GitOps tome el control
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

LOCAL_DEMO="${LOCAL_DEMO:-0}"
[[ "${1:-}" == "--local" ]] && LOCAL_DEMO=1

MINIKUBE_MEMORY="${MINIKUBE_MEMORY:-3584}"
MINIKUBE_CPUS="${MINIKUBE_CPUS:-4}"
GIT_REVISION="${GIT_REVISION:-main}"
ARGOCD_NAMESPACE="argocd"
APP_NAMESPACE="shortlink"
MONITORING_NAMESPACE="monitoring"

# --- 0. Pre-flight -----------------------------------------------------------
info "=== Pre-flight ==="
"$SCRIPT_DIR/bootstrap.sh"
docker info >/dev/null 2>&1 || die "El daemon de Docker no está corriendo."

# --- 1. Cluster --------------------------------------------------------------
info "=== Arrancando minikube (${MINIKUBE_MEMORY}MB / ${MINIKUBE_CPUS} CPUs) ==="
minikube start \
  --driver=docker \
  --memory="$MINIKUBE_MEMORY" \
  --cpus="$MINIKUBE_CPUS" \
  --cni=auto \
  --wait=all

info "Habilitando addons: ingress + metrics-server (HPA)"
minikube addons enable ingress   >/dev/null 2>&1 || true
minikube addons enable metrics-server >/dev/null 2>&1 || true

ok "Cluster listo: $(minikube status --format '{{.Host}}: {{.APIServer}}')"

# --- 2. Imágenes de la app ---------------------------------------------------
info "=== Construyendo imágenes de la app (cargadas en minikube) ==="
# shellcheck disable=SC1091
eval "$(minikube docker-env)"
docker build -q -t shortlink-api:dev "$PROJECT_ROOT/app/api"   | tail -1
docker build -q -t shortlink-web:dev "$PROJECT_ROOT/app/web"   | tail -1
ok "Imágenes: shortlink-api:dev, shortlink-web:dev"

# --- 3. Namespaces + ArgoCD + controllers ------------------------------------
info "=== Instalando ArgoCD + Argo Rollouts + Sealed Secrets (Helm) ==="
kubectl create namespace "$ARGOCD_NAMESPACE" >/dev/null 2>&1 || true
kubectl create namespace "$APP_NAMESPACE"    >/dev/null 2>&1 || true
kubectl create namespace "$MONITORING_NAMESPACE" >/dev/null 2>&1 || true

helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo add sealed-secrets https://bitnami.github.io/sealed-secrets >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true

helm upgrade --install argocd argo/argo-cd \
  --namespace "$ARGOCD_NAMESPACE" \
  --values "$PROJECT_ROOT/deploy/argocd/values.yaml" \
  --wait --timeout 5m

# Argo Rollouts: controller para las estrategias canary del Rollout de la web.
# Se instala ANTES de aplicar las apps (el CRD del Rollout debe existir).
helm upgrade --install argo-rollouts argo/argo-rollouts \
  --namespace argo-rollouts --create-namespace \
  --wait --timeout 3m

# Sealed Secrets: controller que descifra los SealedSecrets del repo.
helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace kube-system \
  --wait --timeout 3m

# Si existe un respaldo de la clave de sellado (de un teardown anterior),
# lo restauramos para que los SealedSecrets commiteados sigan descifrándose
# aunque el cluster se haya recreado.
SEALED_KEY_BACKUP="${SEALED_KEY_BACKUP:-$HOME/.shortlink/sealed-secrets-key.yaml}"
if [[ -f "$SEALED_KEY_BACKUP" ]]; then
  kubectl apply -f "$SEALED_KEY_BACKUP" >/dev/null
  kubectl -n kube-system rollout restart deployment sealed-secrets >/dev/null 2>&1 || true
  ok "Clave de Sealed Secrets restaurada desde $SEALED_KEY_BACKUP"
fi

# Esperar a que el servidor de ArgoCD esté levantado
wait_for "ArgoCD server" 300 "kubectl -n $ARGOCD_NAMESPACE get deployment argocd-server -o jsonpath='{.status.readyReplicas}' | grep -q 1"

ARGO_PASSWORD="$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
ok "ArgoCD UI: https://127.0.0.1:8080  (usuario: admin / password: $ARGO_PASSWORD)"

# --- 4. GitOps: AppProject + app-of-apps -------------------------------------
info "=== Aplicando AppProject y app-of-apps ==="
kubectl apply -f "$PROJECT_ROOT/deploy/argocd/project.yaml" >/dev/null

if [[ "$LOCAL_DEMO" == "1" ]]; then
  info "Modo local: levantando git daemon y aplicando apps desde la copia local"
  "$SCRIPT_DIR/demo-local-git.sh"
else
  if grep -rq "REPLACE_ME" "$PROJECT_ROOT/deploy/argocd/apps/" 2>/dev/null; then
    warn "Los manifests de ArgoCD aún apuntan al placeholder REPLACE_ME."
    warn "  Opción A: reemplázalo por tu repo de GitHub en deploy/argocd/apps/*.yaml"
    warn "  Opción B: usa el modo local: scripts/setup.sh --local"
  else
    kubectl apply -f "$PROJECT_ROOT/deploy/argocd/apps/" >/dev/null
  fi
fi

# --- 5. Resumen --------------------------------------------------------------
echo
echo "==================================================================="
echo "  ShortLink GitOps - entorno listo 🚀"
echo "==================================================================="
echo "  Para acceder a todo (pestañas del demo):"
echo "    scripts/forward.sh"
echo
echo "  ArgoCD   : http://localhost:8080   (admin / $ARGO_PASSWORD)"
echo "  App Web  : http://localhost:8081"
echo "  Grafana  : http://localhost:3000   (admin / admin)"
echo
echo "  El demo guionado está en docs/DEMO.md"
echo "==================================================================="
