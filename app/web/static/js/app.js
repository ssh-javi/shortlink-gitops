'use strict';

/* ShortLink frontend — talks to the API through nginx (/api/*). */

const API_BASE = '/api';

const $ = (sel) => document.querySelector(sel);

const form = $('#shorten-form');
const urlInput = $('#url-input');
const slugInput = $('#slug-input');
const btn = $('#shorten-btn');
const resultBox = $('#result');
const shortUrlLink = $('#short-url');
const copyBtn = $('#copy-btn');
const linksList = $('#links-list');
const linkCount = $('#link-count');
const toast = $('#toast');

function showToast(message, isError = false) {
  toast.textContent = message;
  toast.classList.remove('hidden', 'error');
  if (isError) toast.classList.add('error');
  clearTimeout(showToast._t);
  showToast._t = setTimeout(() => toast.classList.add('hidden'), 3500);
}

async function api(path, options = {}) {
  const res = await fetch(`${API_BASE}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });
  if (res.status === 204) return null;
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = new Error(body.message || body.error || 'Error de red');
    err.status = res.status;
    throw err;
  }
  return body;
}

async function shorten(event) {
  event.preventDefault();
  const url = urlInput.value.trim();
  if (!url) return;

  btn.disabled = true;
  btn.textContent = 'Acortando…';
  try {
    const payload = { url };
    const slug = slugInput.value.trim();
    if (slug) payload.slug = slug;

    const link = await api('/links', { method: 'POST', body: JSON.stringify(payload) });
    const shortUrl = new URL(`/${link.slug}`, window.location.origin).toString();

    resultBox.classList.remove('hidden');
    shortUrlLink.href = shortUrl;
    shortUrlLink.textContent = shortUrl;
    showToast('¡Enlace creado! ⚡');
    urlInput.value = '';
    slugInput.value = '';
    loadLinks();
  } catch (err) {
    showToast(err.message, true);
  } finally {
    btn.disabled = false;
    btn.textContent = 'Acortar';
  }
}

async function loadLinks() {
  try {
    const { links } = await api('/links?limit=25');
    renderLinks(links || []);
  } catch {
    renderLinks([]);
  }
}

function renderLinks(links) {
  linkCount.textContent = `${links.length} enlaces`;
  if (!links.length) {
    linksList.innerHTML = '<li class="empty-state">Todavía no hay enlaces. ¡Acorta el primero! 🚀</li>';
    return;
  }
  linksList.innerHTML = '';
  links.forEach((link) => {
    const shortUrl = new URL(`/${link.slug}`, window.location.origin).toString();
    const li = document.createElement('li');
    li.className = 'link-item';

    const main = document.createElement('div');
    main.className = 'link-main';
    const slug = document.createElement('div');
    slug.className = 'link-slug';
    const a = document.createElement('a');
    a.href = shortUrl;
    a.textContent = `/${link.slug}`;
    a.target = '_blank';
    a.rel = 'noopener';
    slug.appendChild(a);
    const dest = document.createElement('div');
    dest.className = 'link-dest';
    dest.textContent = link.url;
    main.append(slug, dest);

    const stats = document.createElement('div');
    stats.className = 'link-stats';
    const visits = document.createElement('span');
    visits.innerHTML = `👀 <b>${link.visits}</b> visitas`;
    const copy = document.createElement('button');
    copy.type = 'button';
    copy.className = 'ghost-btn';
    copy.textContent = 'Copiar';
    copy.addEventListener('click', async () => {
      await copyText(shortUrl);
      showToast('Copiado al portapapeles ✂️');
    });
    const del = document.createElement('button');
    del.type = 'button';
    del.className = 'delete-btn';
    del.title = 'Eliminar';
    del.textContent = '✕';
    del.addEventListener('click', async () => {
      try {
        await api(`/links/${link.slug}`, { method: 'DELETE' });
        showToast('Enlace eliminado');
        loadLinks();
      } catch (err) {
        showToast(err.message, true);
      }
    });
    stats.append(visits, copy, del);

    li.append(main, stats);
    linksList.appendChild(li);
  });
}

async function copyText(text) {
  try {
    await navigator.clipboard.writeText(text);
  } catch {
    const ta = document.createElement('textarea');
    ta.value = text;
    document.body.appendChild(ta);
    ta.select();
    document.execCommand('copy');
    ta.remove();
  }
}

form.addEventListener('submit', shorten);
copyBtn.addEventListener('click', () => copyText(shortUrlLink.href));

loadLinks();
