'use strict';

const Redis = require('ioredis');
const { config } = require('./config');
const { cacheHitsTotal, cacheMissesTotal } = require('./metrics');

let client;

function connect() {
  client = new Redis(config.redisUrl, {
    lazyConnect: true,
    maxRetriesPerRequest: 2,
    retryStrategy: (times) => Math.min(times * 200, 2000),
    enableOfflineQueue: true,
  });
  client.on('error', (err) => {
    console.error('[redis] error:', err.message);
  });
  return client;
}

async function ensureClient() {
  if (!client) connect();
  return client;
}

async function ping() {
  const c = await ensureClient();
  return (await c.ping()) === 'PONG';
}

/**
 * Read a slug->url mapping from cache.
 * Cache is best-effort: any failure degrades to a DB lookup, never an error.
 */
async function getCached(slug) {
  const c = await ensureClient();
  try {
    const value = await c.get(`link:${slug}`);
    if (value) {
      cacheHitsTotal.inc();
      return value;
    }
    cacheMissesTotal.inc();
    return null;
  } catch (err) {
    cacheMissesTotal.inc();
    return null;
  }
}

async function setCached(slug, url, ttlSeconds = 300) {
  const c = await ensureClient();
  try {
    await c.set(`link:${slug}`, url, 'EX', ttlSeconds);
  } catch (_) {
    /* best-effort */
  }
}

async function invalidate(slug) {
  const c = await ensureClient();
  try {
    await c.del(`link:${slug}`);
  } catch (_) {
    /* best-effort */
  }
}

async function close() {
  if (client) {
    await client.quit();
    client = undefined;
  }
}

module.exports = { connect, ping, getCached, setCached, invalidate, close };
