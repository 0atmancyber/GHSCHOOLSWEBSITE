README: Deploying the SMS proxy (Edge Function)
===============================================

Overview
--------
This workspace includes a ready-to-deploy Supabase Edge Function at `supabase_send_sms_function/index.ts`.
The function forwards SMS send requests to Arkesel (or a compatible SMS gateway) and can optionally
record a row in your Supabase `sms_messages` table via the REST API.

Security
--------
- Never commit API keys or credentials to the repo.
- Store Arkesel credentials and any Supabase service key in the environment of the deployed function.

Environment variables (required / recommended)
---------------------------------------------
- `ARKESEL_API_KEY` (required) — your Arkesel API key
- `ARKESEL_API_EMAIL` (required) — gateway account email
- `ARKESEL_API_URL` (optional) — default: `https://app.arkesel.com/api/sms/send`
- `ARKESEL_SENDER_ID` (optional) — sender id, default `GH_SCHOOLS`
- `SUPABASE_URL` (optional) — your Supabase project URL (for optional logging)
- `SUPABASE_SERVICE_KEY` (optional) — service role key used to write to `sms_messages` table

Deploying to Supabase Functions (recommended)
--------------------------------------------
1. Install and authenticate the Supabase CLI: https://supabase.com/docs/guides/cli
2. Create a functions folder in your project (if not using the repo layout already).
3. Copy `supabase_send_sms_function/index.ts` into your functions directory.
4. Run: `supabase functions deploy send-sms --project-ref <your-project-ref>`
5. Set environment variables for the function in Supabase dashboard → Functions → (your function) → Settings

Deploying to other hosts (Vercel/Render/Railway)
-----------------------------------------------
- You can also deploy this function as a simple Node/Edge worker or serverless function. If deploying
  outside Deno, adapt the code to your platform (the README includes an example payload).
- Ensure environment variables are configured in your host's settings.

Example request (client -> proxy)
---------------------------------
POST /send-sms
Content-Type: application/json

{
  "phone": "233xxxxx...",
  "message": "Hello, your payment was received. Ref: REF123",
  "student_id": "GHMS01026",
  "meta": { "payment_id": "MANUAL-..." }
}

Example curl (test)
-------------------
curl -X POST '<YOUR_FUNCTION_URL>' \
  -H 'Content-Type: application/json' \
  -d '{"phone":"233xxxxxxx","message":"Test from proxy","student_id":"TEST001"}'

Front-end configuration
-----------------------
Set the deployed function URL in your front-end before making calls. Example snippet for your HTML pages:

<script>
  // Put your deployed function URL here. Do NOT commit secrets into client code.
  if (typeof window.PROXY_ENDPOINT === 'undefined') window.PROXY_ENDPOINT = 'https://<YOUR_FUNCTION_HOST>/send-sms';
</script>

Client-side usage (example)
---------------------------
fetch(window.PROXY_ENDPOINT, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ phone: '233xxxxxxx', message: 'Hello', student_id: 'GHMS01026' })
});

Creating the `sms_messages` table (if not present)
-------------------------------------------------
Execute this in Supabase SQL editor or run it from your DB migration tooling.

```sql
create table if not exists sms_messages (
  id uuid default gen_random_uuid() primary key,
  student_id text,
  recipient text,
  phone text,
  message text,
  status text,
  gateway_response jsonb,
  meta jsonb,
  sent_at timestamptz,
  created_at timestamptz default now()
);

alter table sms_messages
  add column if not exists sent_at timestamptz,
  add column if not exists created_at timestamptz default now();
```

Notes & next steps
------------------
- After deployment, set `window.PROXY_ENDPOINT` in the front-end pages (`dashboard.html`, `level100admindashboard.html`, `100dashboard.html`).
- Use the `SUPABASE_SERVICE_KEY` only in server-side environment variables — never in client code.
- If you'd like, I can patch the three dashboard files to include a placeholder `window.PROXY_ENDPOINT` and a short in-page note pointing to this README.

If you want me to produce an equivalent Node/Express or Vercel Worker version, say so and I'll add it.
