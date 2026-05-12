/* ============================================================
   STK · Admin core
   shared: supabase client, auth guard, sidebar, toast, helpers
   ============================================================ */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = 'https://dhfyjdkazhxkhddnacsq.supabase.co';
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_qKcopQkE1zFa2ifMMIkVow_q4i1Xi1J';

export const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    storage: localStorage,
    storageKey: 'stk-admin-auth',
  },
});

/* ----- toasts ----- */
export function toast(msg, kind = '') {
  let el = document.createElement('div');
  el.className = 'toast' + (kind === 'err' ? ' toast--err' : '');
  el.textContent = msg;
  document.body.appendChild(el);
  requestAnimationFrame(() => el.classList.add('show'));
  setTimeout(() => {
    el.classList.remove('show');
    setTimeout(() => el.remove(), 300);
  }, 2400);
}

/* ----- auth guard ----- */
export async function requireAuth() {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) {
    location.href = 'index.html';
    return null;
  }
  return session;
}

/* ----- sidebar shell ----- */
export function renderShell({ current, session }) {
  const email = session?.user?.email ?? '—';
  const sidebar = document.querySelector('.sidebar');
  if (!sidebar) return;

  const links = [
    { href: 'dashboard.html', label: 'Overview', key: 'dashboard' },
    { href: 'products.html', label: 'Products',  key: 'products'  },
    { href: 'inbox.html',    label: 'Inbox',     key: 'inbox'     },
    { href: 'activity.html', label: 'Activity',  key: 'activity'  },
  ];

  sidebar.innerHTML = `
    <a class="sidebar__brand" href="dashboard.html">STK <small>admin</small></a>
    <div class="sidebar__group">Manage</div>
    <nav class="sidebar__nav">
      ${links.map(l => `
        <a class="sidebar__link${l.key === current ? ' current' : ''}" href="${l.href}">
          <span>${l.label}</span>
          <span class="pill" data-count="${l.key}"></span>
        </a>
      `).join('')}
    </nav>
    <div class="sidebar__group">Public site</div>
    <nav class="sidebar__nav">
      <a class="sidebar__link" href="../index.html" target="_blank">View store ↗</a>
    </nav>
    <div class="sidebar__foot">
      <span>Signed in as</span>
      <strong>${email}</strong>
      <button id="signOut">Sign out</button>
    </div>
  `;

  document.getElementById('signOut').addEventListener('click', async () => {
    await supabase.auth.signOut();
    location.href = 'index.html';
  });
}

/* ----- sidebar counts ----- */
export async function refreshCounts() {
  const tables = ['products', 'contact_submissions', 'newsletter_subscribers', 'bag_events'];
  const counts = {};
  await Promise.all(tables.map(async (t) => {
    const { count } = await supabase.from(t).select('id', { count: 'exact', head: true });
    counts[t] = count ?? 0;
  }));

  const map = {
    products: counts.products,
    inbox: counts.contact_submissions,
    activity: counts.bag_events,
  };
  Object.entries(map).forEach(([k, v]) => {
    document.querySelectorAll(`[data-count="${k}"]`).forEach(el => {
      el.textContent = v ?? '';
    });
  });
  return counts;
}

/* ----- format ----- */
export function fmtDate(iso) {
  if (!iso) return '—';
  const d = new Date(iso);
  return d.toLocaleString('en-GB', {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  });
}

export function fmtPrice(cents) {
  if (cents == null) return '—';
  return 'IDR ' + (cents / 1000).toLocaleString('en-US') + 'K';
}

export function escape(str) {
  return String(str ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}
