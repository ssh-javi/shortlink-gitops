# 📐 Decisiones técnicas (ADRs)

Cada decisión importante está documentada como un ADR (Architecture Decision
Record). En una entrevista, poder explicar **el porqué** de cada elección vale
más que la elección misma.

---

## ADR-001 · ArgoCD en vez de Flux

**Contexto:** necesitaba un motor de GitOps para sincronizar el cluster con el
repo.

**Decisión:** ArgoCD.

**Alternativas:** Flux v2.

| Criterio | ArgoCD | Flux |
|---|---|---|
| UI web + RBAC | ✅ Excelente | Básica |
| Adopción de mercado | Muy alta (la más demandada en ofertas) | Alta |
| Instalación | Helm chart maduro | Bootstrap CLI |
| App-of-apps | Nativo | Posible pero más manual |

**Consecuencia:** mejor UI para el demo visual (fundamental al grabar) y la
mayor demanda laboral actual.

---

## ADR-002 · App-of-apps + Helm charts versionados

**Contexto:** muchos manifiestos que orquestar (app, observabilidad,
dashboards).

**Decisión:** patrón **app-of-apps**: un Application raíz vigila
`deploy/argocd/apps/` y gestiona las apps hijas. La app se empaqueta en un
**Helm chart propio**; la observabilidad usa el chart oficial
kube-prometheus-stack con values en Git (multi-source `$values`).

**Por qué:** separa "qué instalo" (apps hijas) de "cómo lo instalo"
(manifiestos), permite activar/desactivar apps sin tocar el cluster y hace que
el chart sea reutilizable en cualquier cluster.

---

## ADR-003 · minikube (local) como entorno del demo

**Contexto:** demo reproducible, gratis, offline-friendly.

**Decisión:** minikube con driver docker.

**Alternativas:** kind, k3s, cloud free tiers.

**Por qué minikube:** ya estaba instalado, soporta addons (ingress,
metrics-server) y es el más cercano a un cluster "real" para el demo. **kind**
es más rápido para CI; se documenta como alternativa. Un cloud free tier se
deja como roadmap para no depender de cuentas/credenciales en el demo.

**Nota RAM:** el stack completo (ArgoCD + kube-prometheus-stack + app) corre
cómodo con 3.5-4 GB asignados a minikube.

---

## ADR-004 · kube-prometheus-stack en vez de componentes sueltos

**Contexto:** observabilidad completa (Prometheus, Grafana, Alertmanager,
exporters, ServiceMonitors).

**Decisión:** kube-prometheus-stack (Helm).

**Por qué:** un solo chart mantiene las piezas alineadas, provisiona el
datasource de Grafana con uid `prometheus`, e incluye dashboards y reglas
estándar de Kubernetes. Con Prometheus Operator, la app declara su scraping
con un **ServiceMonitor** (self-service de observabilidad — mentalidad
platform engineering).

---

## ADR-005 · Secretos versionados en Git (solo demo)

**Contexto:** necesitaba un stack reproducible sin dependencias externas.

**Decisión:** las credenciales demo viven en `values.yaml` (Helm → Secret).

**Por qué:** para el demo. **Advertencia explícita:** en producción se usaría
**External Secrets Operator + Vault/SOPS** y el repo no contendría secretos.

**Riesgo aceptado:** el cluster es local y desechable.

---

## ADR-006 · Node.js para la API

**Contexto:** app demo de negocio, fácil de entender.

**Decisión:** Node.js 22 + Express, CJS.

**Por qué:** es el stack más legible para un recruiter (sin compilación),
imagen final pequeña (~60 MB con alpine), y `prom-client` da métricas
Prometheus nativas sin sidecar. La **inyección de dependencias** en `app.js`
permite tests unitarios sin BD real.

---

## ADR-007 · CI nunca toca el cluster (GitOps puro)

**Contexto:** cómo entregan las nuevas versiones.

**Decisión:** CI construye + publica imágenes y **actualiza el estado deseado
en Git** (`values.ci.yaml`). ArgoCD hace el rollout.

**Por qué:** CI sin permisos de cluster = menor superficie de ataque y
auditabilidad total. El rollout es un diff visible en ArgoCD, no magia negra
de un pipeline.

---

## ADR-008 · Imágenes inmutables por sha + latest

**Contexto:** trazabilidad de versiones.

**Decisión:** tag `sha-<commit>` (inmutable, trazable) y `latest` (comodidad).
El *promote* de CI escribe el sha exacto.

**Por qué:** puedes saber qué código corre en producción con solo mirar el tag;
rollback = apuntar al sha anterior.

---

## ADR-009 · Helm chart único (app + dependencias) en vez de micro-charts

**Contexto:** empaquetar la app demo.

**Decisión:** un solo chart `shortlink` con 5 workloads (api, web, redis,
postgres).

**Por qué:** es un demo; un chart por microservicio (estilo microservices
charts) añade complejidad sin valor aquí. La estructura de templates está
preparada para extraer sub-charts si el proyecto creciera.

---

## Trade-offs reconocidos

- **Reducir recursos de Prometheus/Grafana** para minikube: pierdes
  rendimiento de scraping, ganas demo en RAM limitada.
- **Storage efímero en Prometheus**: las métricas se pierden al reiniciar el
  pod. Aceptable para demo; en producción se usaría un PV/Thanos.
- **Redis sin password**: mitigado con NetworkPolicy (opt-in) y porque el
  cluster es local. En producción: Redis con TLS + auth (o servicio
  gestionado).
