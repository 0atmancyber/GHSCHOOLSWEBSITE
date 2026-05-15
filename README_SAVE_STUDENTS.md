Overview

This folder contains a small Express server (`server.js`) that accepts JSON POSTs at `/api/newstudents` and inserts into `public.newstudents`.

Setup

1. Copy `.env.example` to `.env` and set `DATABASE_URL`.

2. Install dependencies:

```bash
npm init -y
npm install express pg dotenv
```

3. Run the server:

```bash
node server.js
```

How it works

- The client-side in `ghfashionforms.html` now wraps the form in `#admissionForm` and posts JSON to `/api/newstudents`.
- Multiple schools are sent in the `schools_attended` array and stored as JSON in the `schools_attended` column.

Notes

- Make sure the DB table `public.newstudents` exists and includes a `schools_attended jsonb` column. If it doesn't, run:

```sql
ALTER TABLE public.newstudents ADD COLUMN IF NOT EXISTS schools_attended jsonb;
```

- The server inserts only fields recognized in the allowed list. Update `allowedCols` in `server.js` if you add new fields.
