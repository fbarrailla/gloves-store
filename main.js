/* ============================================================
   SARUNG TANGAN KIPER · main.js
   classic sportswear e-commerce
   ============================================================ */

(() => {
  'use strict';

  const CART_KEY = 'stk_bag_v3';

  function readCart() {
    try { return JSON.parse(localStorage.getItem(CART_KEY)) || []; }
    catch { return []; }
  }
  function writeCart(c) {
    localStorage.setItem(CART_KEY, JSON.stringify(c));
    renderCart();
  }
  function renderCart() {
    const c = readCart();
    document.querySelectorAll('[data-cart-count]').forEach(el => {
      el.textContent = c.length;
    });
  }
  window.addToQueue = function () {
    const c = readCart();
    const sku = document.title.split(' ')[0];
    c.push({ sku, at: Date.now() });
    writeCart(c);
    if (window.STKSupabase?.trackBagAdd) window.STKSupabase.trackBagAdd(sku);
    const last = document.activeElement;
    if (last && last.classList.contains('btn')) {
      const original = last.textContent;
      last.textContent = '✓ Added to bag';
      setTimeout(() => { last.textContent = original; }, 1600);
    }
  };

  // ---------- catalog filter checkboxes (multi-select) ----------
  document.addEventListener('change', (e) => {
    const cb = e.target.closest('input[type="checkbox"][data-filter]');
    if (!cb) return;
    const active = Array.from(document.querySelectorAll('input[type="checkbox"][data-filter]:checked'))
      .map(x => x.dataset.filter);
    document.querySelectorAll('#grid .card').forEach(card => {
      const ok = active.length === 0 || active.includes(card.dataset.cut);
      card.style.display = ok ? '' : 'none';
    });
  });

  // clear filters
  document.addEventListener('click', (e) => {
    const btn = e.target.closest('.btn--ghost');
    if (!btn || btn.textContent.trim() !== 'Clear filters') return;
    e.preventDefault();
    document.querySelectorAll('input[type="checkbox"][data-filter]').forEach(x => x.checked = false);
    document.querySelectorAll('#grid .card').forEach(c => c.style.display = '');
  });

  // ---------- size selector ----------
  document.addEventListener('click', (e) => {
    const s = e.target.closest('.size');
    if (!s || s.classList.contains('size--out')) return;
    e.preventDefault();
    const group = s.parentElement;
    group.querySelectorAll('.size--on').forEach(x => x.classList.remove('size--on'));
    s.classList.add('size--on');
  });

  // ---------- color swatches on PDP — retint hero image ----------
  document.addEventListener('click', (e) => {
    const sw = e.target.closest('.swatch, .swatch-dot');
    if (!sw) return;
    e.preventDefault();
    if (sw.parentElement.matches('.swatches, .swatches-row')) {
      sw.parentElement.querySelectorAll('.swatch--on, .swatch-dot--on').forEach(x => {
        x.classList.remove('swatch--on');
        x.classList.remove('swatch-dot--on');
      });
      sw.classList.add(sw.classList.contains('swatch') ? 'swatch--on' : 'swatch-dot--on');
    }

    const visual = document.getElementById('visual');
    if (!visual) return;
    const label = (sw.getAttribute('aria-label') || '').toLowerCase();
    if (label.includes('oxblood')) {
      visual.style.background = 'oklch(0.30 0.10 28)';
    } else if (label.includes('bone')) {
      visual.style.background = 'oklch(0.86 0.012 80)';
      visual.style.color = 'var(--ink)';
    } else if (label.includes('ash')) {
      visual.style.background = 'oklch(0.40 0.012 70)';
    } else if (label.includes('ink')) {
      visual.style.background = '';
      visual.style.color = '';
    }
  });

  // ---------- gallery thumbnails ----------
  document.addEventListener('click', (e) => {
    const t = e.target.closest('.thumb');
    if (!t) return;
    e.preventDefault();
    t.parentElement.querySelectorAll('.on').forEach(x => x.classList.remove('on'));
    t.classList.add('on');

    // Swap the main image when a photo thumbnail is clicked
    const src = t.dataset.img;
    const mainImg = document.getElementById('pdp-image');
    if (src && mainImg) {
      mainImg.src = src;
      const inner = t.querySelector('img');
      if (inner && inner.alt) mainImg.alt = inner.alt;
      return;
    }

    // Legacy: SVG thumbs re-tint the background
    const visual = document.getElementById('visual');
    if (!visual) return;
    if (t.classList.contains('thumb--paper')) {
      visual.style.background = 'var(--paper)';
      visual.style.color = 'var(--ink)';
    } else if (t.classList.contains('thumb--bone')) {
      visual.style.background = 'var(--bone)';
      visual.style.color = 'var(--ink)';
    } else if (t.classList.contains('thumb--strike')) {
      visual.style.background = 'var(--strike-soft)';
      visual.style.color = 'var(--ink)';
    } else {
      visual.style.background = '';
      visual.style.color = '';
    }
  });

  // ---------- reveal animations ----------
  if ('IntersectionObserver' in window) {
    const io = new IntersectionObserver((entries) => {
      for (const e of entries) {
        if (e.isIntersecting) {
          e.target.classList.add('in');
          io.unobserve(e.target);
        }
      }
    }, { threshold: 0.1, rootMargin: '0px 0px -8% 0px' });

    document.querySelectorAll('.section, .pdp, .featured, .tiles, .about-hero').forEach(el => {
      el.classList.add('reveal');
      io.observe(el);
    });
  }

  renderCart();
})();
