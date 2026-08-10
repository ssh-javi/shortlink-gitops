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

## ADR-005 · Secretos con Sealed Secrets (cifrado en el repo)

**Contexto:** necesitaba un stack reproducible sin dependencias externas,
pero con **cero secretos en claro en Git** (el repo es público).

**Decisión:** **Bitnami Sealed Secrets**. El `Secret` de la app se genera en el
cluster a partir de un `SealedSecret` commitado, cifrado con la clave pública
del controller (scope namespace-wide). Nada sensible vive en `values.yaml`.

**Por qué:** permite GitOps puro (todo en el repo) sin exponer credenciales ni
depender de un proveedor externo de secretos (Vault) para el demo.

**Alternativas:** External Secrets Operator + Vault/SOPS (producción), que se
deja como roadmap.

**Operación:** `scripts/teardown.sh` respalda la clave de sellado en
`~/.shortlink/sealed-secrets-key.yaml`; `setup.sh` la restaura si existe, así
los SealedSecrets commiteados siguen descifrándose aunque el cluster se
recreé. En un cluster/máquina nueva sin el respaldo, `scripts/seal-secret.sh`
regenera el SealedSecret con la clave del controller actual (también sirve
para rotar la password).

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

## ADR-010 · Argo Rollouts para progressive delivery (canary)

**Contexto:** cómo entregar cambios sin riesgo. El Deployment con
`RollingUpdate` lo hacía, pero sin control fino ni verificación de métricas.

**Decisión:** la web se despliega con un **Rollout de Argo Rollouts**
(estrategia canary + `trafficRouting` nginx + análisis de métricas).

**Por qué:** progressive delivery de verdad — 20% → 50% → 100% del tráfico,
pausas configurables y **rollback automático** si la tasa de error de la API
supera el 5% (AnalysisTemplate + Prometheus). Es el skill más demandado en
GitOps/Plataforma y el momento más vistoso del demo.

**Por qué solo la web:** es el edge (todo el tráfico pasa por ella). La API
queda como Deployment; migrarla es un cambio de template trivial.

**Trade-off:** ArgoCD debe ignorar las mutaciones del controller sobre el
Ingress y los Services (ver `ignoreDifferences` en `01-shortlink.yaml`), y el
controller `argo-rollouts` es un componente extra que instala `setup.sh`.

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
