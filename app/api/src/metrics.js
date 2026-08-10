'use strict';

const client = require('prom-client');

const registry = new client.Registry();
client.collectDefaultMetrics({ register: registry });

// HTTP latency histogram - feeds the Grafana latency panel + latency alert
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],
  registers: [registry],
});

// HTTP request counter - feeds the request-rate + error-rate panels
const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status'],
  registers: [registry],
});

// Business metrics: how many redirects has the service served?
const shortlinkVisitsTotal = new client.Counter({
  name: 'shortlink_visits_total',
  help: 'Total number of redirects served by ShortLink',
  registers: [registry],
});

// Cache effectiveness: hit ratio = hits / (hits + misses)
const cacheHitsTotal = new client.Counter({
  name: 'shortlink_cache_hits_total',
  help: 'Total number of cache hits',
  registers: [registry],
});

const cacheMissesTotal = new client.Counter({
  name: 'shortlink_cache_misses_total',
  help: 'Total number of cache misses',
  registers: [registry],
});

/** Express middleware that records method/route/status + latency for every request. */
function httpMetricsMiddleware(req, res, next) {
  const start = process.hrtime.bigint();
  res.on('finish', () => {
    const durationSeconds = Number(process.hrtime.bigint() - start) / 1e9;
    // Build a stable route label, e.g. /api/links, /health, /:slug
    let route = 'unmatched';
    if (req.route && req.route.path) {
      const base = req.baseUrl || '';
      route = base + (req.route.path === '/' ? '' : req.route.path) || base;
    }
    const status = String(res.statusCode);
    httpRequestDuration.observe({ method: req.method, route, status }, durationSeconds);
    httpRequestsTotal.inc({ method: req.method, route, status });
  });
  next();
}

/** Prometheus text exposition handler. */
async function metricsHandler(_req, res) {
  // setHeader works both on Express responses and on the raw http.ServerResponse
  // used by the metrics-only server on :9100 (res.set is Express-only).
  res.setHeader('Content-Type', registry.contentType);
  res.end(await registry.metrics());
}

module.exports = {
  registry,
  httpMetricsMiddleware,
  metricsHandler,
  httpRequestDuration,
  httpRequestsTotal,
  shortlinkVisitsTotal,
  cacheHitsTotal,
  cacheMissesTotal,
};
