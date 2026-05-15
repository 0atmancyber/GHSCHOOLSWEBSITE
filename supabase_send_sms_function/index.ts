// Supabase Edge Function: send-sms
// Deploy this to your Supabase Functions (Deno) or similar Edge environment.
// This function forwards SMS send requests to Arkesel and (optionally)
// records a row into the Supabase `sms_messages` table using the REST API.

export default async function handler(req: Request) {
  // CORS headers for browser requests
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };

  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: corsHeaders,
    });
  }

  try {
    if (req.method !== 'POST') return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers: corsHeaders });

    const body = await req.json().catch(() => null);
    if (!body) return new Response(JSON.stringify({ error: 'Invalid JSON body' }), { status: 400, headers: corsHeaders });

    const { phone, phones, message, student_id, meta } = body;
    const recipients = Array.isArray(phones) ? phones : (phones ? [phones] : (Array.isArray(phone) ? phone : (phone ? [phone] : [])));
    if (!recipients || recipients.length === 0) return new Response(JSON.stringify({ error: 'Recipient phone missing' }), { status: 400, headers: corsHeaders });

    const ARKESEL_API_URL = Deno.env.get('ARKESEL_API_URL') || 'https://app.arkesel.com/api/sms/send';
    const ARKESEL_API_KEY = Deno.env.get('ARKESEL_API_KEY');
    const ARKESEL_API_EMAIL = Deno.env.get('ARKESEL_API_EMAIL');
    const ARKESEL_SENDER_ID = Deno.env.get('ARKESEL_SENDER_ID') || 'GH_SCHOOLS';

    if (!ARKESEL_API_KEY || !ARKESEL_API_EMAIL) {
      return new Response(JSON.stringify({ error: 'Missing gateway credentials in environment' }), { status: 500, headers: corsHeaders });
    }

    // Build provider payload (adjust keys if Arkesel expects different names)
    const payload = {
      to: recipients,
      body: message,
      from: ARKESEL_SENDER_ID,
      email: ARKESEL_API_EMAIL,
      api_key: ARKESEL_API_KEY
    };

    const arRes = await fetch(ARKESEL_API_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    }).catch(err => ({ ok: false, error: String(err) }));

    let arResult = null;
    try {
      if (arRes && typeof arRes.json === 'function') arResult = await arRes.json();
      else arResult = arRes;
    } catch (e) { arResult = { raw: String(arRes) }; }

    // Optionally record to Supabase via REST (requires SUPABASE_URL and SUPABASE_SERVICE_KEY env vars)
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
    const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_KEY');
    if (SUPABASE_URL && SUPABASE_SERVICE_KEY) {
      try {
        const record = {
          student_id: student_id || null,
          recipient: recipients.join(','),
          phone: recipients.join(','),
          message: message || null,
          status: (arResult && (arResult.status || (arResult.success ? 'sent' : 'unknown'))) || 'unknown',
          gateway_response: arResult || null,
          meta: meta || null,
          created_at: new Date().toISOString()
        };

        await fetch(`${SUPABASE_URL.replace(/\/+$/, '')}/rest/v1/sms_messages`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'apikey': SUPABASE_SERVICE_KEY,
            'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`
          },
          body: JSON.stringify([record])
        });
      } catch (e) {
        // best-effort logging; do not fail the request on logging errors
        console.warn('Supabase logging failed:', e);
      }
    }

    return new Response(JSON.stringify({ ok: true, result: arResult }), { status: 200, headers: corsHeaders });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), { status: 500, headers: corsHeaders });
  }
}
