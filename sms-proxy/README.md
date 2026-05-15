GHMedia SMS Proxy

This small Node/Express proxy forwards SMS send requests from the admin dashboard to the Arkesel SMS API while keeping API credentials server-side.

Security note: Do NOT commit your real `.env` file to source control. Use `.env` or environment variables in production.

Setup (Windows PowerShell):

```powershell
# from workspace root
cd "c:\Users\DELL\Documents\ghmedia\sms-proxy"
# copy example env
copy .env.example .env
# Edit .env to confirm values (Open-Editor or edit with notepad)
# Install deps
npm install
# Start proxy
npm start
```

Default endpoint:
- POST /send-sms
  - JSON body: { "to": "233XXXXXXXXX", "message": "Text here" }
  - Returns Arkesel response or an error

Example test (PowerShell):

```powershell
# replace number with a real test number in Ghana format
$body = @{ to = '23324XXXXXXXX'; message = 'Test from GHMedia proxy' } | ConvertTo-Json
curl -Method POST -Uri http://localhost:3000/send-sms -Body $body -ContentType 'application/json'
```

Notes:
- The proxy uses `ARKESEL_API_URL` and forwards the payload with `email`, `api_key`, `sender_id`, `to`, `message`. If Arkesel expects a different payload/headers, update `app.js` accordingly.
- For production, deploy behind HTTPS and secure the endpoint (e.g., require authentication or allowlist IPs).

Importing phone numbers into Supabase
-----------------------------------

You can bulk-import phone numbers into your `students` table using the included script.

1. Install additional dependencies in the `sms-proxy` folder:

```powershell
cd "C:\Users\DELL\Documents\ghmedia\sms-proxy"
npm install @supabase/supabase-js csv-parse dotenv
```

2. Create a `.env` with your Supabase service role key (keep this secret):

```
SUPABASE_URL=https://YOUR-PROJECT.supabase.co
SUPABASE_SERVICE_KEY=YOUR_SERVICE_ROLE_KEY
```

3. Prepare a CSV named like `sample_phones.csv` with header `student_id,phone` (a sample file is included).

4. Run the import:

```powershell
node import-phones.js sample_phones.csv
```

The script will normalize phone numbers (leading `0` -> `233`), batch the rows, and upsert them into the `students` table on `student_id`.

Security note: the import script requires a Supabase service role key which has elevated privileges — do not commit this key.
