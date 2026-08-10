'use strict';

/**
 * Centralised configuration. Every value can be overridden via environment
 * variables (12-factor style). Kubernetes injects these via ConfigMap/Secret.
 */

function parsePort(value, fallback) {
  const n = Number.parseInt(value, 10);
  return Number.isInteger(n) && n > 0 && n < 65536 ? n : fallback;
}

// Clamp an integer env var into [min, max]; falls back on unparsable input.
function clampInt(value, fallback, min, max) {
  const n = Number.parseInt(value, 10);
  if (!Number.isInteger(n)) return fallback;
  return Math.min(max, Math.max(min, n));
}

const config = {
  env: process.env.NODE_ENV || 'development',
  port: parsePort(process.env.PORT, 3000),
  metricsPort: parsePort(process.env.METRICS_PORT, 9100),
  databaseUrl:
    process.env.DATABASE_URL ||
    'postgres://shortlink:shortlink@localhost:5432/shortlink',
  redisUrl: process.env.REDIS_URL || 'redis://localhost:6379',
  slugLength: parsePort(process.env.SLUG_LENGTH, 7),
  baseUrl: process.env.BASE_URL || 'http://localhost:8081',
  logLevel: process.env.LOG_LEVEL || 'info',
  version: process.env.APP_VERSION || 'dev',
  // Chaos-engineering hook: % of business requests that fail with 500.
  // Used by the canary demo to prove Argo Rollouts' automatic rollback.
  // 0 = disabled. Health/metrics endpoints are never affected.
  simulateErrorRate: clampInt(process.env.SIMULATE_ERROR_RATE, 0, 0, 100),
};

module.exports = { config };
