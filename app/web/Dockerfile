# =============================================================================
# ShortLink Web - static frontend served by an unprivileged nginx
# nginx proxies /api/* and /<slug> to the API service in-cluster.
# =============================================================================

FROM nginxinc/nginx-unprivileged:1.27-alpine

# Non-root by default: the image runs as uid 101 without a USER directive.

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY static/ /usr/share/nginx/html/

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/ || exit 1
