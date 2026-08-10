'use strict';

const request = require('supertest');
const { createApp } = require('../src/app');

function fakeDb(overrides = {}) {
  return {
    ping: async () => true,
    insertLink: async ({ slug, url }) => ({
      id: 1,
      slug,
      url,
      visits: 0,
      created_at: new Date(),
    }),
    findLink: async () => null,
    listLinks: async () => [],
    incrementVisits: async () => {},
    deleteLink: async () => null,
    ...overrides,
  };
}

function fakeCache(overrides = {}) {
  return {
    ping: async () => true,
    getCached: async () => null,
    setCached: async () => {},
    invalidate: async () => {},
    ...overrides,
  };
}

describe('POST /api/links', () => {
  const app = createApp({ db: fakeDb(), cache: fakeCache() });

  test.each(['not-a-url', 'ftp://example.com', 'javascript:alert(1)', '', null])(
    'rejects invalid URL %p',
    async (url) => {
      const res = await request(app).post('/api/links').send({ url });
      expect(res.status).toBe(400);
    }
  );

  test('creates a link and returns a short URL', async () => {
    const res = await request(app)
      .post('/api/links')
      .send({ url: 'https://example.com/very/long/path?q=1' });
    expect(res.status).toBe(201);
    expect(res.body.slug).toMatch(/^[a-zA-Z0-9]{7}$/);
    expect(res.body.shortUrl).toContain(res.body.slug);
    expect(res.body.visits).toBe(0);
  });

  test('honours a custom slug', async () => {
    const res = await request(app)
      .post('/api/links')
      .send({ url: 'https://example.com', slug: 'mi-link' });
    expect(res.status).toBe(201);
    expect(res.body.slug).toBe('mi-link');
  });

  test('returns 409 when the slug is already taken', async () => {
    const db = fakeDb();
    db.insertLink = async () => {
      const err = new Error('duplicate');
      err.code = '23505';
      throw err;
    };
    const customApp = createApp({ db, cache: fakeCache() });
    const res = await request(customApp)
      .post('/api/links')
      .send({ url: 'https://example.com' });
    expect(res.status).toBe(409);
  });
});

describe('GET /:slug redirects', () => {
  test('serves a redirect from cache', async () => {
    const cache = fakeCache({ getCached: async () => 'https://cached.example.com' });
    const app = createApp({ db: fakeDb(), cache });
    const res = await request(app).get('/abc1234');
    expect(res.status).toBe(302);
    expect(res.headers.location).toBe('https://cached.example.com');
  });

  test('falls back to the database and warms the cache', async () => {
    let cached = null;
    const db = fakeDb({
      findLink: async (slug) =>
        slug === 'db12345' ? { slug, url: 'https://db.example.com', visits: 1 } : null,
    });
    const cache = fakeCache({
      getCached: async () => cached,
      setCached: async (_slug, url) => {
        cached = url;
      },
    });
    const app = createApp({ db, cache });
    const res = await request(app).get('/db12345');
    expect(res.status).toBe(302);
    expect(res.headers.location).toBe('https://db.example.com');
    expect(cached).toBe('https://db.example.com');
  });

  test('returns 404 for an unknown slug', async () => {
    const app = createApp({ db: fakeDb(), cache: fakeCache() });
    const res = await request(app).get('/nope123');
    expect(res.status).toBe(404);
  });
});

describe('GET /health', () => {
  test('reports ok when dependencies are up', async () => {
    const app = createApp({ db: fakeDb(), cache: fakeCache() });
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.components.database).toBe('up');
    expect(res.body.components.cache).toBe('up');
  });

  test('reports degraded when the database is down', async () => {
    const db = fakeDb({
      ping: async () => {
        throw new Error('connection refused');
      },
    });
    const app = createApp({ db, cache: fakeCache() });
    const res = await request(app).get('/health');
    expect(res.status).toBe(503);
    expect(res.body.status).toBe('degraded');
  });

  test('liveness always answers ok', async () => {
    const app = createApp({ db: fakeDb(), cache: fakeCache() });
    const res = await request(app).get('/health/live');
    expect(res.status).toBe(200);
  });
});

describe('GET /api/links', () => {
  test('lists links', async () => {
    const db = fakeDb({
      listLinks: async () => [{ slug: 'abc', url: 'https://x.com', visits: 3 }],
    });
    const app = createApp({ db, cache: fakeCache() });
    const res = await request(app).get('/api/links');
    expect(res.status).toBe(200);
    expect(res.body.links).toHaveLength(1);
  });

  test('returns 404 for unknown API routes', async () => {
    const app = createApp({ db: fakeDb(), cache: fakeCache() });
    const res = await request(app).get('/api/nope');
    expect(res.status).toBe(404);
  });
});

describe('failure injection (SIMULATE_ERROR_RATE)', () => {
  const { config } = require('../src/config');

  afterEach(() => {
    config.simulateErrorRate = 0;
  });

  test('returns 500 for business requests when the rate is 100', async () => {
    config.simulateErrorRate = 100;
    const app = createApp({ db: fakeDb(), cache: fakeCache() });
    const res = await request(app).get('/api/links');
    expect(res.status).toBe(500);
  });

  test('does not affect the health endpoint', async () => {
    config.simulateErrorRate = 100;
    const app = createApp({ db: fakeDb(), cache: fakeCache() });
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });

  test('does not affect the metrics endpoint', async () => {
    config.simulateErrorRate = 100;
    const app = createApp({ db: fakeDb(), cache: fakeCache() });
    const res = await request(app).get('/metrics');
    expect(res.status).toBe(200);
    expect(res.text).toContain('http_requests_total');
  });
});
