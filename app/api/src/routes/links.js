'use strict';

const express = require('express');
const { customAlphabet } = require('nanoid');

const { config } = require('../config');
const { shortlinkVisitsTotal } = require('../metrics');

const nanoid = customAlphabet(
  'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
  config.slugLength
);

const SLUG_PATTERN = /^[a-zA-Z0-9_-]{3,20}$/;

function isValidUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === 'http:' || url.protocol === 'https:';
  } catch (_) {
    return false;
  }
}

/** CRUD API for short links. */
function linksRouter({ db, cache }) {
  const router = express.Router();

  // Create a short link: POST /api/links { url, slug? }
  router.post('/', async (req, res, next) => {
    try {
      const { url, slug } = req.body || {};

      if (typeof url !== 'string' || !isValidUrl(url)) {
        return res.status(400).json({
          error: 'invalid_url',
          message: 'Provide a valid http(s) URL.',
        });
      }

      const finalSlug =
        typeof slug === 'string' && SLUG_PATTERN.test(slug) ? slug : nanoid();

      const link = await db.insertLink({ slug: finalSlug, url });
      res.status(201).json({
        ...link,
        visits: Number(link.visits),
        shortUrl: `${config.baseUrl}/${link.slug}`,
      });
    } catch (err) {
      // Unique violation on the slug column
      if (err && err.code === '23505') {
        return res.status(409).json({
          error: 'slug_taken',
          message: 'That slug is already in use, try another one.',
        });
      }
      next(err);
    }
  });

  // List recent links: GET /api/links?limit=50
  router.get('/', async (req, res, next) => {
    try {
      const parsed = Number.parseInt(req.query.limit, 10);
      const limit = Number.isInteger(parsed) ? Math.min(parsed, 100) : 50;
      const links = await db.listLinks(limit);
      res.json({ links });
    } catch (err) {
      next(err);
    }
  });

  // Stats for one link: GET /api/links/:slug/stats
  router.get('/:slug/stats', async (req, res, next) => {
    try {
      const link = await db.findLink(req.params.slug);
      if (!link) return res.status(404).json({ error: 'not_found' });
      res.json({ slug: link.slug, url: link.url, visits: Number(link.visits) });
    } catch (err) {
      next(err);
    }
  });

  // Delete: DELETE /api/links/:slug
  router.delete('/:slug', async (req, res, next) => {
    try {
      const removed = await db.deleteLink(req.params.slug);
      if (!removed) return res.status(404).json({ error: 'not_found' });
      await cache.invalidate(req.params.slug);
      res.status(204).end();
    } catch (err) {
      next(err);
    }
  });

  return router;
}

/** Redirect engine for GET /:slug - the hot path, cached in Redis. */
function redirectRouter({ db, cache }) {
  const router = express.Router();

  router.get('/:slug', async (req, res, next) => {
    try {
      const { slug } = req.params;

      // 1. Try the cache first (fast path)
      let url = await cache.getCached(slug);

      // 2. Fall back to the database and warm the cache
      if (!url) {
        const link = await db.findLink(slug);
        if (!link) {
          return res.status(404).json({
            error: 'not_found',
            message: 'Short link not found.',
          });
        }
        url = link.url;
        await cache.setCached(slug, url);
      }

      // 3. Count the visit (fire-and-forget, never block the redirect)
      await db.incrementVisits(slug).catch(() => {});
      shortlinkVisitsTotal.inc();

      return res.redirect(302, url);
    } catch (err) {
      next(err);
    }
  });

  return router;
}

module.exports = { linksRouter, redirectRouter, isValidUrl };
