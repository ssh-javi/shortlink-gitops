# 🎬 Guion para grabar tu demo (12 minutos)

Este guion está pensado para grabar con **OBS Studio** (gratis) o cualquier
grabadora de pantalla. La idea es que **cuentes una historia**, no que
muestres comandos sueltos.

> 💡 **Consejo:** graba primero la pantalla y luego añade tu voz. Ensaya una
> vez sin grabar. Si te equivocas, no pares: repite la frase y edítalo después.

---

## Preparación (antes de grabar)

```bash
# 1. Levanta el entorno
scripts/setup.sh

# 2. Abre las pestañas (en este orden, para el guion)
scripts/forward.sh
#   Tab 1: http://localhost:8080  ArgoCD
#   Tab 2: http://localhost:8081  Web (ShortLink)
#   Tab 3: http://localhost:3000  Grafana
```

Consejos de grabación con OBS:
- Resolución 1920×1080, 30 fps.
- Escena 1: pantalla completa (pestañas).
- Escena 2: zoom sobre el código/terminal (usa una captura de ventana).
- No muestres el password de ArgoCD en pantalla por más de 2 segundos, o
  cúbrelo — es un demo, pero es buena práctica.

---

## Guion narrado

### 0. Intro (0:00 – 0:45)
> "Hola, soy **[tu nombre]**. Este es mi proyecto de DevOps: un acortador de
> URLs desplegado con un flujo **GitOps** completo. Lo importante no es la app,
> sino **el sistema alrededor de ella**: pipeline CI/CD, despliegues
> declarativos, observabilidad y seguridad. Todo corriendo en mi máquina con
> costo **cero**."

### 1. El problema y la solución (0:45 – 1:45)
> "El problema que resolví: desplegar microservicios a mano es lento y nadie
> sabe qué versión está en producción. Mi solución: **Git es la única fuente de
> verdad**. Toda la infraestructura y la app viven como código. Un push
> desencadena CI, y ArgoCD aplica el estado deseado al cluster."

- Muestra la estructura del repo (`tree` o el README).
- Muestra `docs/ARCHITECTURE.md` y el diagrama de flujo.

### 2. La app (1:45 – 3:30)
> "La app es un acortador de URLs: una API en Node.js, un frontend, una base
> PostgreSQL y Redis como caché."

- Crea un enlace en la web (Tab 2): pega una URL larga → "Acortar".
- Haz clic en el enlace corto y muestra que redirige.
- Copia el enlace y muéstralo en una pestaña incógnito.

### 3. Observabilidad en vivo (3:30 – 5:30)
> "Como DevOps, necesitas ver qué está pasando. La API expone métricas en
> `:9100/metrics` que Prometheus scrapea. Grafana las muestra en vivo."

- Tab 3 (Grafana): muestra el dashboard **ShortLink Overview**.
- Haz **5-10 clicks** en enlaces cortos y muestra cómo suben las métricas de
  visitas en vivo. ⭐ *Este momento es oro: métricas de negocio en tiempo real.*
- Señala el panel de latencia y cache hit ratio y explica: *"el cache hit
  ratio sube porque Redis absorbe las lecturas repetidas"*.

### 4. El pipeline CI/CD (5:30 – 7:00)
> "Cada cambio pasa por el pipeline. Acabo de cambiar algo en el frontend."

- Ve a GitHub → Actions → muestra el workflow corriendo (o ya completado).
- Explica los jobs: `test`, `validate-manifests` (helm lint + kubeconform),
  `scan` (Trivy), `build-and-push` (ghcr.io), `promote`.

### 5. El corazón: GitOps con ArgoCD (7:00 – 9:30) ⭐
> "Y aquí está lo importante: CI **no** toca el cluster. Solo actualiza el
> estado deseado en Git. ArgoCD ve el cambio y sincroniza."

- Tab 1 (ArgoCD): muestra la vista de aplicaciones.
- Selecciona la app `shortlink` → pestaña *Sync Status* / *App Details*.
- Muestra el árbol de recursos: 2 pods de API, 2 de web, postgres, redis.
- **Demo del self-healing** ⭐:
  ```bash
  # Borra un pod a mano (esto NO se debe hacer en producción 😄)
  kubectl -n shortlink delete pod -l app.kubernetes.io/component=api
  ```
  Muestra cómo ArgoCD lo recrea en segundos.
- **Demo del sync automático**: cambia algo en el código (o simplemente haz
  click en *Sync* / *Refresh*) y muestra el rollout.

### 6. Rollback (9:30 – 10:30) ⭐
> "¿Y si una versión sale mal? Rollback = revert en Git."

```bash
# Simula un problema y reviértelo
git log --oneline -5
git revert HEAD --no-edit        # vuelve a la versión anterior
./scripts/setup.sh --local       # actualiza el repo local (si usas modo local)
```
- Muestra en ArgoCD cómo el estado deseado vuelve atrás y el cluster lo sigue.

### 7. Alertas (10:30 – 11:15)
> "También configuré alertas. Si la tasa de error sube del 5%, o la latencia
> p95 pasa de 500ms, Prometheus dispara una alerta."

- Muestra `deploy/monitoring/kube-prometheus-stack-values.yaml` (las reglas).
- Opcional: en Grafana → *Alerting* muestra las reglas cargadas.

### 8. Cierre (11:15 – 12:00)
> "Resumen: CI/CD automático, despliegues GitOps con rollback instantáneo,
> observabilidad de negocio e infraestructura, seguridad desde la imagen hasta
> el pod, y todo con herramientas open source y costo cero. El código está en
> [link]. Gracias por verlo — ¿preguntas?"

---

## Checklist antes de publicar

- [ ] Creé al menos 5 enlaces cortos para que el dashboard no esté vacío.
- [ ] El dashboard de Grafana muestra métricas (refresca con F5 si hace falta).
- [ ] ArgoCD muestra las 3 apps con estado **Synced** (verde).
- [ ] Probé el self-healing una vez para no equivocarme en cámara.
- [ ] El video tiene buena iluminación/audio (prueba con el teléfono si no
      tienes micrófono).
- [ ] Subí el repo a GitHub **antes** de grabar (para mostrar Actions reales).

## Herramientas de grabación gratis

| Herramienta | Uso |
|---|---|
| [OBS Studio](https://obsproject.com/) | Grabación profesional de pantalla |
| [DaVinci Resolve](https://www.blackmagicdesign.com/products/davinciresolve) | Edición (opcional) |
| [Loom](https://www.loom.com/) (plan free) | Alternativa rápida en la nube |
| [Vokoscreen](https://linuxecke.volkoh.de/vokoscreen/vokoscreen.html) | Alternativa ligera en Linux |
