# 📖 Glosario

Términos usados en el proyecto, explicados para que cualquiera (recruiter o
DevOps Lead) entienda el repo sin fricción.

| Término | Qué significa aquí |
|---|---|
| **GitOps** | Git es la única fuente de verdad del estado del cluster. ArgoCD compara Git vs. cluster y aplica las diferencias. |
| **ArgoCD** | Herramienta open source de GitOps. Mantiene las apps sincronizadas con un repo Git. |
| **App-of-apps** | Patrón de ArgoCD: un Application "raíz" gestiona otras Applications. Escala la gestión GitOps. |
| **Helm** | "Package manager" de Kubernetes. Un *chart* empaqueta manifiestos parametrizables. |
| **AppProject** | Objeto de ArgoCD que agrupa aplicaciones y define permisos (destinos, fuentes). |
| **ServiceMonitor** | Recurso del Prometheus Operator: declara *qué* scrapear. La app declara su propia observabilidad. |
| **kube-prometheus-stack** | Chart Helm que instala Prometheus, Grafana, Alertmanager y exporters en conjunto. |
| **PrometheusRule** | Declaración de alertas de Prometheus como código. |
| **HPA** (Horizontal Pod Autoscaler) | Escala el número de réplicas según métricas (aquí, CPU al 70%). |
| **PDB** (Pod Disruption Budget) | Garantiza un mínimo de pods disponibles durante mantenimientos. |
| **Probes (readiness/liveness)** | Chequeos del kubelet: readiness = ¿recibe tráfico? liveness = ¿reinicio el pod? |
| **Multi-stage Dockerfile** | Build en etapas: la imagen final solo lleva lo necesario para correr. |
| **Trivy** | Escáner de vulnerabilidades de imágenes/archivos (open source). |
| **ghcr.io** | GitHub Container Registry: almacén de imágenes Docker gratuito. |
| **kubeconform** | Valida manifiestos YAML contra los esquemas oficiales de Kubernetes. |
| **StatefulSet** | Workload para apps con estado (aquí, PostgreSQL con su PVC). |
| **PVC** (PersistentVolumeClaim) | Petición de almacenamiento persistente. |
| **NetworkPolicy** | Reglas de firewall entre pods (zero-trust). Requiere CNI con soporte (p.ej. Cilium). |
| **RollingUpdate** | Estrategia de despliegue: pods nuevos primero, cortar tráfico solo cuando pasan las probes. |
| **Self-healing** | ArgoCD restaura el estado deseado si alguien lo modifica a mano. |
| **Promote** | Paso del pipeline que actualiza el estado deseado en Git (el tag de la imagen). |
