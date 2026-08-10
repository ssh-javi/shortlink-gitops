'use strict';

/**
 * Centralised configuration. Every value can be overridden via environment
 * variables (12-factor style). Kubernetes injects these via ConfigMap/Secret.
 */

function parsePort(value, fallback) {
  const n = Number.parseInt(value, 10);
  return Number.isInteger(n) && n > 0 && n < 65536 ? n : fallback;
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
};

module.exports = { config };
