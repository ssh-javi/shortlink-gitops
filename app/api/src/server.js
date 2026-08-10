'use strict';

const http = require('http');

const { config } = require('./config');
const db = require('./db');
const cache = require('./redis');
const { createApp } = require('./app');
const { metricsHandler } = require('./metrics');

async function main() {
  // Fail fast: if the schema can't be created the pod will be restarted by k8s
  await db.initSchema();
  await cache.connect();

  const app = createApp({ db, cache });
  const server = http.createServer(app);
  server.listen(config.port, () => {
    console.log(`[server] shortlink-api listening on :${config.port} (${config.env})`);
  });

  // Metrics on a separate port: scraping never competes with user traffic
  const metricsServer = http.createServer((req, res) => {
    if (req.url === '/metrics') return metricsHandler(req, res);
    res.statusCode = 404;
    res.end();
  });
  metricsServer.listen(config.metricsPort, () => {
    console.log(`[server] prometheus metrics on :${config.metricsPort}`);
  });

  // Graceful shutdown: stop accepting traffic, drain, close connections
  let shuttingDown = false;
  function shutdown(signal) {
    if (shuttingDown) return;
    shuttingDown = true;
    console.log(`[server] ${signal} received, draining connections...`);
    const forceExit = setTimeout(() => process.exit(1), 10_000);
    forceExit.unref();
    server.close();
    metricsServer.close();
    db.close()
      .then(() => cache.close())
      .then(() => {
        console.log('[server] shutdown complete');
        process.exit(0);
      })
      .catch((err) => {
        console.error('[server] error during shutdown:', err);
        process.exit(1);
      });
  }
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

main().catch((err) => {
  console.error('[server] fatal error:', err);
  process.exit(1);
});
