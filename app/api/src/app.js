'use strict';

const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

const { config } = require('./config');
const { httpMetricsMiddleware, metricsHandler } = require('./metrics');
const { linksRouter, redirectRouter } = require('./routes/links');
const { healthRouter } = require('./routes/health');

/**
 * App factory. Dependencies (db, cache) are injected so the same app can be
 * tested with fakes and run for real in production.
 */
function createApp({ db, cache }) {
  const app = express();

  app.disable('x-powered-by');
  app.use(helmet());
  app.use(httpMetricsMiddleware);
  app.use(express.json({ limit: '64kb' }));

  // Prometheus scraping endpoint
  app.use('/metrics', metricsHandler);

  // Readiness / liveness
  app.use('/health', healthRouter({ db, cache }));

  // Chaos-engineering hook: simulates 5xx for SIMULATE_ERROR_RATE% of
  // business requests (health/metrics excluded so probes + scraping keep
  // working). Used by the canary rollback demo. 0 = disabled.
  app.use((req, _res, next) => {
    if (
      config.simulateErrorRate > 0 &&
      !req.path.startsWith('/health') &&
      !req.path.startsWith('/metrics') &&
      Math.random() * 100 < config.simulateErrorRate
    ) {
      const err = new Error('simulated failure (SIMULATE_ERROR_RATE)');
      err.statusCode = 500;
      return next(err);
    }
    return next();
  });

  // API (rate-limited to protect the database from abusive bursts)
  const apiLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 100,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'rate_limited', message: 'Too many requests, slow down.' },
  });
  app.use('/api/links', apiLimiter, linksRouter({ db, cache }));

  // Root info
  app.get('/', (_req, res) => {
    res.json({ name: 'shortlink-api', version: config.version, health: '/health' });
  });

  // Redirect short links (must be mounted after specific routes)
  app.use('/', redirectRouter({ db, cache }));

  // 404 + error handlers
  app.use((_req, res) => res.status(404).json({ error: 'not_found' }));
  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    console.error('[app] unhandled error:', err);
    res.status(500).json({ error: 'internal_error' });
  });

  return app;
}

module.exports = { createApp };
