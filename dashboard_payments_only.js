
// dashboard.js — Payments-only version (no students table)
(() => {
  'use strict';

  const $ = (sel) => document.querySelector(sel);
  const $$ = (sel) => Array.from(document.querySelectorAll(sel));
  const fmtCurrency = (v) => {
    const n = Number(v || 0);
    return 'GHS ' + n.toLocaleString('en-GH', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  };
  const fmtDate = (s) => {
    const d = new Date(s);
    if (isNaN(d)) return s || '';
    return d.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: '2-digit' });
  };
  const badgeClass = (status) => {
    const s = (status || '').toLowerCase();
    if (s === 'paid') return 'paid';
    if (s === 'pending') return 'pending';
    if (s === 'refunded') return 'refunded';
    return '';
  };
  const escapeHtml = (s) => (s || '').replace(/[&<>"']/g, (c) => ({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'
  })[c]);

  // ---------- State ----------
  let supabase = null;
  const state = { payments: [] };

  // ---------- Config ----------
  const supabaseUrl = localStorage.getItem('supabaseUrl') || '';
  const supabaseKey = localStorage.getItem('supabaseKey') || '';
  if (!supabaseUrl || !supabaseKey) {
    console.warn('Supabase URL/Key missing — set them in Settings.');
  } else if (!window.supabase) {
    console.error('Supabase JS SDK not found.');
  } else {
    supabase = window.supabase.createClient(supabaseUrl, supabaseKey);
  }

  // ---------- Fetch ----------
  async function fetchPayments() {
    if (!supabase) return;
    const { data, error } = await supabase
      .from('payments')
      .select('payment_id, created_at, student_id, student_name, department, level, payment_type, amount, status, transaction_ref')
      .order('created_at', { ascending: false });
    if (error) { console.error('fetchPayments:', error); return; }
    state.payments = data || [];
  }

  // ---------- Aggregation ----------
  function kpiTotals() {
    let total = 0, tuition = 0, other = 0, cnt = 0;
    for (const p of state.payments) {
      if ((p.status || '').toLowerCase() === 'paid') {
        cnt += 1;
        const amt = Number(p.amount || 0);
        total += amt;
        if ((p.payment_type || '').toLowerCase().includes('tuition')) tuition += amt;
        else other += amt;
      }
    }
    return { total, tuition, other, cnt };
  }

  function perStudentSums() {
    const map = new Map();
    for (const p of state.payments) {
      if ((p.status || '').toLowerCase() !== 'paid') continue;
      const key = p.student_id;
      const entry = map.get(key) || { name: p.student_name, id: p.student_id, level: p.level, dept: p.department, tuition: 0, other: 0 };
      const amt = Number(p.amount || 0);
      if ((p.payment_type || '').toLowerCase().includes('tuition')) entry.tuition += amt;
      else entry.other += amt;
      map.set(key, entry);
    }
    return map;
  }

  // ---------- Rendering ----------
  function renderKPIs() {
    const { total, tuition, other, cnt } = kpiTotals();
    $('#kpiTotal').textContent = fmtCurrency(total);
    $('#kpiTuition').textContent = fmtCurrency(tuition);
    $('#kpiOther').textContent = fmtCurrency(other);
    $('#kpiCount').textContent = String(cnt);
  }

  function renderPaymentsTable() {
    const tbody = $('#paymentsTable tbody');
    if (!tbody) return;
    tbody.innerHTML = '';

    const q = ($('#globalSearch')?.value || '').toLowerCase();
    for (const p of state.payments) {
      const hay = `${p.payment_id} ${p.student_id} ${p.student_name} ${p.department} ${p.level} ${p.payment_type} ${p.status} ${p.transaction_ref}`.toLowerCase();
      if (q && !hay.includes(q)) continue;

      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td>${fmtDate(p.created_at)}</td>
        <td>${escapeHtml(p.payment_id)}</td>
        <td>${escapeHtml(p.student_name || '-')} (${escapeHtml(p.student_id)})</td>
        <td>${escapeHtml(p.payment_type || '-')}</td>
        <td>${fmtCurrency(p.amount)}</td>
        <td><span class="badge ${badgeClass(p.status)}">${escapeHtml(p.status || '-')}</span></td>
        <td>${escapeHtml(p.transaction_ref || '-')}</td>
        <td><button class="btn ghost" data-action="history" data-student="${escapeHtml(p.student_id)}">History</button></td>
      `;
      tbody.appendChild(tr);
    }
    $('#paymentsMeta').textContent = `${tbody.children.length} payments shown`;
  }

  function renderStudentsTable() {
    const tbody = $('#studentsTable tbody');
    if (!tbody) return;
    tbody.innerHTML = '';

    const sums = perStudentSums();
    for (const entry of sums.values()) {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td>${escapeHtml(entry.name || '-')}</td>
        <td>${escapeHtml(entry.id || '-')}</td>
        <td>${escapeHtml(entry.level || '-')}</td>
        <td>${escapeHtml(entry.dept || '-')}</td>
        <td>${fmtCurrency(entry.tuition)}</td>
        <td>${fmtCurrency(entry.other)}</td>
        <td><button class="btn ghost" data-action="history" data-student="${escapeHtml(entry.id)}">History</button></td>
      `;
      tbody.appendChild(tr);
    }
    $('#studentsMeta').textContent = `${tbody.children.length} students shown`;
  }

  function renderAll() {
    renderKPIs();
    renderPaymentsTable();
    renderStudentsTable();
  }

  // ---------- Modal ----------
  function openStudentHistory(studentId) {
    const history = state.payments.filter(p => p.student_id === studentId);
    const student = history[0] || { student_name: studentId, student_id: studentId };
    let total = 0;
    const perType = new Map();
    for (const p of history) {
      if ((p.status || '').toLowerCase() !== 'paid') continue;
      const key = p.payment_type || 'Other';
      const prev = perType.get(key) || 0;
      const amt = Number(p.amount || 0);
      perType.set(key, prev + amt);
      total += amt;
    }
    const breakdown = Array.from(perType.entries()).map(([k, v]) => `<li>${escapeHtml(k)}: <strong>${fmtCurrency(v)}</strong></li>`).join('');
    const rows = history.map(p => `
      <tr>
        <td>${fmtDate(p.created_at)}</td>
        <td>${escapeHtml(p.payment_id)}</td>
        <td>${escapeHtml(p.payment_type || '-')}</td>
        <td>${fmtCurrency(p.amount)}</td>
        <td>${escapeHtml(p.status || '-')}</td>
        <td>${escapeHtml(p.transaction_ref || '-')}</td>
      </tr>
    `).join('');

    const html = `
      <div class="panel" style="max-width:960px;">
        <h2>Payment History — ${escapeHtml(student.student_name)} <span class="muted">(${escapeHtml(student.student_id)})</span></h2>
        <div style="display:flex; gap:20px; flex-wrap:wrap; margin:10px 0;">
          <div class="card" style="flex:1 1 220px;"><h3>Total Paid</h3><div class="value">${fmtCurrency(total)}</div></div>
          <div class="card" style="flex:1 1 220px;"><h3>By Fee Type</h3><ul style="margin-top:8px; line-height:1.8;">${breakdown || '<li>No paid fees yet</li>'}</ul></div>
        </div>
        <div style="overflow:auto; max-height:420px;">
          <table>
            <thead><tr><th>Date</th><th>Payment ID</th><th>Fee Type</th><th>Amount</th><th>Status</th><th>Ref</th></tr></thead>
            <tbody>${rows}</tbody>
          </table>
        </div>
        <div style="margin-top:14px; text-align:right;"><button class="btn primary" id="closeModal">Close</button></div>
      </div>`;
    showModal(html, { width: '980px' });
  }

  function showModal(innerHTML, opts = {}) {
    let overlay = $('#modalOverlay');
    if (!overlay) {
      overlay = document.createElement('div');
      overlay.id = 'modalOverlay';
      overlay.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.45);display:flex;align-items:center;justify-content:center;z-index:9999;padding:20px;';
      document.body.appendChild(overlay);
    }
    overlay.innerHTML = `<div style="background:#fff;border-radius:16px;box-shadow:0 24px 80px rgba(0,0,0,.25);width:${opts.width || 'min(100%, 1000px)'};max-height:90vh;overflow:auto;">${innerHTML}</div>`;
    overlay.addEventListener('click', (e) => { if (e.target.id === 'modalOverlay' || e.target.id === 'closeModal') overlay.remove(); });
  }

  // ---------- Events ----------
  function bindEvents() {
    $('#paymentsTable')?.addEventListener('click', (e) => {
      const btn = e.target.closest('button[data-action="history"]');
      if (btn) openStudentHistory(btn.dataset.student);
    });
    $('#studentsTable')?.addEventListener('click', (e) => {
      const btn = e.target.closest('button[data-action="history"]');
      if (btn) openStudentHistory(btn.dataset.student);
    });
    $('#globalSearch')?.addEventListener('input', () => { renderPaymentsTable(); renderStudentsTable(); });
  }

  // ---------- Realtime ----------
  async function subscribeRealtime() {
    if (!supabase) return;
    const channel = supabase.channel('realtime:payments');
    channel.on('postgres_changes', { event: '*', schema: 'public', table: 'payments' }, (payload) => {
      // Refresh all data instead of patching (simpler)
      fetchPayments().then(renderAll);
    });
    await channel.subscribe();
  }

  // ---------- Init ----------
  async function init() {
    bindEvents();
    if (!supabase) return;
    await fetchPayments();
    renderAll();
    subscribeRealtime();
  }
  init();
})();
