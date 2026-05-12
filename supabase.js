/* ============================================================
   STK · Supabase client
   ============================================================
   Uses the @supabase/supabase-js v2 client loaded from esm.sh.
   The publishable key below is safe to expose in client code —
   security is enforced by RLS policies in the database.
   ============================================================ */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = 'https://dhfyjdkazhxkhddnacsq.supabase.co';
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_qKcopQkE1zFa2ifMMIkVow_q4i1Xi1J';

export const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  auth: { persistSession: false },
});

/* ------------------------------------------------------------
   Newsletter — anyone can subscribe their email
   ------------------------------------------------------------ */
export async function subscribeNewsletter(email) {
  const { error } = await supabase
    .from('newsletter_subscribers')
    .insert({ email, source: location.pathname });
  if (error && error.code !== '23505') throw error; // 23505 = duplicate email, treat as success
}

/* ------------------------------------------------------------
   Contact form — custom-pair inquiries from /about
   ------------------------------------------------------------ */
export async function sendContactMessage({ name, email, subject, message }) {
  const { error } = await supabase
    .from('contact_submissions')
    .insert({ name, email, subject, message });
  if (error) throw error;
}

/* ------------------------------------------------------------
   Bag events — fire-and-forget add-to-bag analytics
   ------------------------------------------------------------ */
export async function trackBagAdd(sku) {
  await supabase
    .from('bag_events')
    .insert({ sku, path: location.pathname })
    .then(() => {}, () => {}); // silent failure — analytics is best-effort
}

/* ------------------------------------------------------------
   Wire up forms on page load
   ------------------------------------------------------------ */
function wireNewsletterForms() {
  document.querySelectorAll('.newsletter form, .colophon__signup, .footer form').forEach((form) => {
    if (form.dataset.wired) return;
    form.dataset.wired = '1';
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      const input = form.querySelector('input[type="email"]');
      const button = form.querySelector('button[type="submit"]') || form.querySelector('button');
      if (!input || !button) return;
      const original = button.textContent;
      button.disabled = true;
      button.textContent = 'Subscribing…';
      try {
        await subscribeNewsletter(input.value.trim());
        button.textContent = '✓ Subscribed';
        input.value = '';
      } catch (err) {
        console.error('Newsletter subscribe failed:', err);
        button.textContent = 'Try again';
        setTimeout(() => { button.textContent = original; button.disabled = false; }, 2000);
        return;
      }
      setTimeout(() => { button.textContent = original; button.disabled = false; }, 2500);
    });
  });
}

function wireContactForm() {
  // Match the form on about.html (3 inputs + textarea + select)
  const form = document.querySelector('#contact form, [id="contact"] form');
  if (!form || form.dataset.wired) return;
  form.dataset.wired = '1';
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const fd = new FormData(form);
    const inputs = form.querySelectorAll('input, textarea, select');
    const payload = {
      name: inputs[0]?.value.trim(),
      email: inputs[1]?.value.trim(),
      subject: inputs[2]?.value.trim(),
      message: inputs[3]?.value.trim(),
    };
    const submit = form.querySelector('button[type="submit"]');
    const original = submit?.textContent;
    if (submit) { submit.disabled = true; submit.textContent = 'Sending…'; }
    try {
      await sendContactMessage(payload);
      if (submit) submit.textContent = '✓ Sent — we will reply within 48h';
      form.reset();
    } catch (err) {
      console.error('Contact send failed:', err);
      if (submit) submit.textContent = 'Try again';
    }
    setTimeout(() => { if (submit) { submit.textContent = original; submit.disabled = false; } }, 3500);
  });
}

document.addEventListener('DOMContentLoaded', () => {
  wireNewsletterForms();
  wireContactForm();
});

// Expose for main.js to call when items are added
window.STKSupabase = { trackBagAdd };
