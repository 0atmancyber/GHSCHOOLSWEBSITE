const express = require('express');
const axios = require('axios');
const bodyParser = require('body-parser');
const cors = require('cors');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(bodyParser.json());

const PORT = process.env.PORT || 3000;
// Defaults taken from the admin dashboard config (can be overridden by environment variables)
const ARKESEL_API_URL = process.env.ARKESEL_API_URL || 'https://app.arkesel.com/api/sms/send';
const ARKESEL_API_KEY = process.env.ARKESEL_API_KEY || 'eRMVry$3QufP5xv';
const ARKESEL_EMAIL = process.env.ARKESEL_EMAIL || 'gh.mediasch@gmail.com';
const ARKESEL_SENDER = process.env.ARKESEL_SENDER || process.env.ARKESEL_SENDER_ID || 'GH_SCHOOLS';
const USE_PROXY = String(process.env.USE_PROXY || 'false').toLowerCase() === 'true';
const PROXY_ENDPOINT = process.env.PROXY_ENDPOINT || '';
const DRY_RUN = String(process.env.DRY_RUN || '0') === '1';

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.SUPABASE_API_URL || '';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || process.env.SERVICE_ROLE_KEY || '';
const bcrypt = require('bcryptjs');

// In-memory reset code store: { key -> { code, expiresAt, student_id, phone } }
const resetCodes = new Map();

if (!ARKESEL_API_KEY || !ARKESEL_EMAIL) {
  console.warn('ARKESEL_API_KEY or ARKESEL_EMAIL not set in environment - proxy will return 500 for requests until configured. See .env.example');
}

app.get('/', (req, res) => {
  res.send('GHMedia SMS Proxy is running. POST /send-sms to send messages.');
});

app.post('/send-sms', async (req, res) => {
  try {
    const { to, message } = req.body;
    if (!to || !message) return res.status(400).json({ error: 'Missing "to" or "message" in body' });

    if (DRY_RUN) {
      return res.json({ ok: true, dryRun: true, to, message });
    }

    // Build payload according to Arkesel-style API (adjust as needed)
    const payload = {
      email: ARKESEL_EMAIL,
      api_key: ARKESEL_API_KEY,
      sender_id: ARKESEL_SENDER,
      to: to,
      message: message
    };

    // Send to provider
    const resp = await axios.post(ARKESEL_API_URL, payload, {
      headers: {
        'Content-Type': 'application/json'
      },
      timeout: 20000
    });

    // Return provider response (text or JSON)
    return res.status(resp.status).send(resp.data);
  } catch (err) {
    console.error('/send-sms error', err?.response?.data || err.message || err);
    const status = err?.response?.status || 500;
    const body = err?.response?.data || { error: String(err.message || err) };
    return res.status(status).send(body);
  }
});

// Request a password reset code: POST /password-reset/request
// Body: { student_id?, email?, phone? }
app.post('/password-reset/request', async (req, res) => {
  try {
    const { student_id, email, phone } = req.body || {};
    if (!student_id && !email && !phone) return res.status(400).json({ error: 'Provide student_id, email or phone' });

    // Generate 6-digit code
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const key = student_id || email || phone;
    const expiresAt = Date.now() + (15 * 60 * 1000); // 15 minutes

    // store code
    resetCodes.set(String(key), { code, expiresAt, student_id, phone, email });

    // Build message
    const message = `Your GH TECH password reset code is: ${code}. Expires in 15 minutes.`;

    if (DRY_RUN) {
      return res.json({ ok: true, dryRun: true, code });
    }

    // If a phone is provided, send via the configured provider
    if (phone) {
      const payload = {
        email: ARKESEL_EMAIL,
        api_key: ARKESEL_API_KEY,
        sender_id: ARKESEL_SENDER,
        to: phone,
        message: message
      };

      try {
        const resp = await axios.post(ARKESEL_API_URL, payload, { headers: { 'Content-Type': 'application/json' }, timeout: 20000 });
        return res.status(resp.status).send({ ok: true, sentTo: phone });
      } catch (err) {
        console.error('send-sms (password reset) error', err?.response?.data || err.message || err);
        return res.status(500).json({ error: 'Failed to send SMS', detail: String(err?.message || err) });
      }
    }

    // If no phone available, just reply OK (code stored) so client can show instructions
    return res.json({ ok: true, message: 'Reset code generated', key: String(key) });
  } catch (err) {
    console.error('/password-reset/request error', err);
    return res.status(500).json({ error: String(err?.message || err) });
  }
});

// Confirm password reset: POST /password-reset/confirm
// Body: { key, code, new_password, student_id }
app.post('/password-reset/confirm', async (req, res) => {
  try {
    const { key, code, new_password, student_id } = req.body || {};
    if (!key || !code || !new_password) return res.status(400).json({ error: 'Missing key, code or new_password' });

    const entry = resetCodes.get(String(key));
    if (!entry) return res.status(400).json({ error: 'No reset request found for that key' });
    if (String(entry.code) !== String(code)) return res.status(400).json({ error: 'Invalid code' });
    if (Date.now() > entry.expiresAt) return res.status(400).json({ error: 'Code expired' });

    // Hash the password
    const hashed = bcrypt.hashSync(String(new_password), 10);

    // Try to update student_master_db table via Supabase REST if service key configured
    if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
      // Remove used code
      resetCodes.delete(String(key));
      return res.json({ ok: true, warning: 'No SUPABASE_SERVICE_KEY configured; code validated but password not saved to DB. Provide SUPABASE_SERVICE_KEY to persist.' });
    }

    // Determine the student identifier to update (prefer provided student_id, then stored student_id or key)
    const targetStudentId = student_id || entry.student_id || entry.email || entry.phone || key;
    if (!targetStudentId) return res.status(400).json({ error: 'Could not determine student identifier for update' });

    // PATCH to student_master_db table where student_id equals the provided identifier
    const restUrl = `${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/student_master_db?student_id=eq.${encodeURIComponent(targetStudentId)}`;
    try {
      const resp = await axios.patch(restUrl, { password_hash: hashed }, {
        headers: {
          'Content-Type': 'application/json',
          'apikey': SUPABASE_SERVICE_KEY,
          'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
          'Prefer': 'return=representation'
        },
        timeout: 20000
      });

      resetCodes.delete(String(key));
      return res.json({ ok: true, updated: resp.data });
    } catch (err) {
      console.error('Failed to update student_master_db table:', err?.response?.data || err.message || err);
      // Keep code valid for one more attempt? For simplicity delete it to avoid replay
      resetCodes.delete(String(key));
      return res.status(500).json({ error: 'Failed to persist new password. Check SUPABASE_URL and SUPABASE_SERVICE_KEY and ensure `students` has `password_hash` column.', detail: String(err?.message || err) });
    }
  } catch (err) {
    console.error('/password-reset/confirm error', err);
    return res.status(500).json({ error: String(err?.message || err) });
  }
});

// Background worker: poll `sms_messages` table for intents and send them automatically
async function processPendingSms() {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) return;
  try {
    const restBase = SUPABASE_URL.replace(/\/+$/, '') + '/rest/v1';
    const headers = {
      'apikey': SUPABASE_SERVICE_KEY,
      'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
      'Content-Type': 'application/json'
    };

    // Fetch a small batch of queued intents
    const qUrl = `${restBase}/sms_messages?status=eq.intent_created&order=created_at.asc&limit=10`;
    const listResp = await axios.get(qUrl, { headers });
    const rows = Array.isArray(listResp.data) ? listResp.data : [];
    for (const row of rows) {
      const id = row.id;
      let phone = row.phone || null;
      let student = null;

      // Try fetching student phone when phone not provided
      if (!phone && row.student_id) {
        try {
          const sUrl = `${restBase}/student_master_db?student_id=eq.${encodeURIComponent(row.student_id)}&select=phone_number_1,phone,phone_number,full_name,first_name,last_name,total_payable`;
          const sResp = await axios.get(sUrl, { headers });
          if (Array.isArray(sResp.data) && sResp.data.length) {
            student = sResp.data[0];
            phone = student.phone_number_1 || student.phone || student.phone_number || null;
          } 
        } catch (e) { /* ignore student fetch failures */ }
      }

      // Compute outstanding balance (best-effort)
      let outstanding = null;
      try {
        if (row.student_id) {
          // sum paid amounts for this student
          const payUrl = `${restBase}/payments?student_id=eq.${encodeURIComponent(row.student_id)}&status=in.(paid,approved)&select=amount`;
          const pResp = await axios.get(payUrl, { headers });
          const payments = Array.isArray(pResp.data) ? pResp.data : [];
          const totalPaid = payments.reduce((s, r) => s + Number(r.amount || 0), 0);
          let totalPayable = null;
          if (student && (student.total_payable || student.totalPayable)) totalPayable = Number(student.total_payable || student.totalPayable);
          if (totalPayable != null && !Number.isNaN(totalPayable)) {
            outstanding = Math.max(totalPayable - totalPaid, 0).toFixed(2);
          }
        }
      } catch (e) { /* ignore outstanding computation errors */ }

      // Build message
      let message = row.message || '';
      if (!message || message.trim() === '') {
        message = `GH TECHNICAL — Hi, we received your payment.`;
      }
      if (outstanding != null) {
        if (message.includes('{outstanding}')) message = message.replace(/{outstanding}/g, `GHS ${outstanding}`);
        else message = `${message} Outstanding balance: GHS ${outstanding}.`;
      } else {
        if (!message.toLowerCase().includes('outstanding')) message = `${message} Please check your student portal for your outstanding balance.`;
      }

      // Dry-run handling
      if (DRY_RUN) {
        try {
          await axios.patch(`${restBase}/sms_messages?id=eq.${id}`, { status: 'sent', gateway_response: 'dry-run' }, { headers });
        } catch (e) { /* ignore */ }
        continue;
      }

      if (!phone) {
        try {
          await axios.patch(`${restBase}/sms_messages?id=eq.${id}`, { status: 'failed', gateway_response: 'no phone found' }, { headers });
        } catch (e) { /* ignore */ }
        continue;
      }

      // Normalize phone (best-effort similar to dashboard helpers)
      function normalizePhoneLocal(ph) {
        if (!ph) return null;
        let d = String(ph).replace(/\D/g, '');
        if (d.charAt(0) === '0') d = '233' + d.slice(1);
        if (d.length < 9) return null;
        return d;
      }

      const toPhone = normalizePhoneLocal(phone);
      if (!toPhone) {
        try {
          await axios.patch(`${restBase}/sms_messages?id=eq.${id}`, { status: 'failed', gateway_response: 'invalid phone' }, { headers });
        } catch (e) { /* ignore */ }
        continue;
      }

      // Send via provider
      try {
        const payload = {
          email: ARKESEL_EMAIL,
          api_key: ARKESEL_API_KEY,
          sender_id: ARKESEL_SENDER,
          to: toPhone,
          message: message
        };
        const sendResp = await axios.post(ARKESEL_API_URL, payload, { headers: { 'Content-Type': 'application/json' }, timeout: 20000 });
        const gw = (sendResp && sendResp.data) ? JSON.stringify(sendResp.data) : String(sendResp.status || 'ok');
        try {
          await axios.patch(`${restBase}/sms_messages?id=eq.${id}`, { status: 'sent', gateway_response: gw, sent_at: new Date().toISOString() }, { headers });
        } catch (e) { /* ignore logging error */ }
      } catch (err) {
        const detail = err && err.response && err.response.data ? JSON.stringify(err.response.data) : String(err && err.message || err);
        try {
          await axios.patch(`${restBase}/sms_messages?id=eq.${id}`, { status: 'failed', gateway_response: detail }, { headers });
        } catch (e) { /* ignore */ }
        console.warn('Failed to send queued SMS id=' + id + ':', detail);
      }

      // small pause to avoid provider bursts
      await new Promise(r => setTimeout(r, 250));
    }
  } catch (err) {
    console.warn('processPendingSms error', err && (err.message || err));
  }
}

// Start processing loop (run once immediately, then every 10s)
(async () => { try { await processPendingSms(); } catch(e){} })();
setInterval(() => { processPendingSms().catch(e => console.warn('processPendingSms loop error', e)); }, 10000);

app.listen(PORT, () => console.log(`GHMedia SMS proxy listening on port ${PORT}`));
