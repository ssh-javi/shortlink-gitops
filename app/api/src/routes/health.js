'use strict';

const express = require('express');
const { config } = require('../config');

function healthRouter({ db, cache }) {
  const router = express.Router();

  // Liveness: the process is up. Used by the kubelet to restart dead pods.
  router.get('/live', (_req, res) => {
    res.json({ status: 'ok' });
  });

  // Readiness: dependencies are reachable. Pods only receive traffic when ok.
  router.get('/', async (_req, res) => {
    let database = 'up';
    let cacheStatus = 'up';
    let databaseOk = true;

    try {
      await db.ping();
    } catch (err) {
      database = 'down';
      databaseOk = false;
      console.error('[health] database:', err.message);
    }

    try {
      await cache.ping();
    } catch (err) {
      cacheStatus = 'down';
      console.error('[health] cache:', err.message);
    }

    const body = {
      status: databaseOk ? 'ok' : 'degraded',
      version: config.version,
      uptimeSeconds: Math.round(process.uptime()),
      components: { database, cache: cacheStatus },
    };

    // The service cannot serve traffic without its database -> 503
    res.status(databaseOk ? 200 : 503).json(body);
  });

  return router;
}

module.exports = { healthRouter };
