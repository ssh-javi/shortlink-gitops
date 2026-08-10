'use strict';

const { Pool } = require('pg');
const { config } = require('./config');

let pool;

function createPool() {
  pool = new Pool({
    connectionString: config.databaseUrl,
    max: 10,
    connectionTimeoutMillis: 2000,
    idleTimeoutMillis: 30000,
  });
  pool.on('error', (err) => {
    console.error('[db] idle client error:', err.message);
  });
  return pool;
}

async function ensurePool() {
  if (!pool) createPool();
  return pool;
}

/** Idempotent schema initialisation, safe to run on every boot. */
async function initSchema() {
  const p = await ensurePool();
  await p.query(`
    CREATE TABLE IF NOT EXISTS links (
      id         BIGSERIAL PRIMARY KEY,
      slug       TEXT UNIQUE NOT NULL,
      url        TEXT NOT NULL,
      visits     BIGINT NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);
}

async function ping() {
  const p = await ensurePool();
  const res = await p.query('SELECT 1');
  return res.rows.length === 1;
}

async function insertLink({ slug, url }) {
  const p = await ensurePool();
  const res = await p.query(
    `INSERT INTO links (slug, url)
     VALUES ($1, $2)
     RETURNING id, slug, url, visits, created_at`,
    [slug, url]
  );
  return res.rows[0];
}

async function findLink(slug) {
  const p = await ensurePool();
  const res = await p.query(
    'SELECT id, slug, url, visits, created_at FROM links WHERE slug = $1',
    [slug]
  );
  return res.rows[0] || null;
}

async function incrementVisits(slug) {
  const p = await ensurePool();
  await p.query('UPDATE links SET visits = visits + 1 WHERE slug = $1', [slug]);
}

async function listLinks(limit = 50) {
  const p = await ensurePool();
  const res = await p.query(
    'SELECT id, slug, url, visits, created_at FROM links ORDER BY created_at DESC LIMIT $1',
    [limit]
  );
  return res.rows;
}

async function deleteLink(slug) {
  const p = await ensurePool();
  const res = await p.query(
    'DELETE FROM links WHERE slug = $1 RETURNING slug',
    [slug]
  );
  return res.rows[0] || null;
}

async function close() {
  if (pool) await pool.end();
}

module.exports = {
  createPool,
  initSchema,
  ping,
  insertLink,
  findLink,
  incrementVisits,
  listLinks,
  deleteLink,
  close,
};
