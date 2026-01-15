-- Supabase / Postgres migration: create `notifications` table
-- Run this in the Supabase SQL editor (or via psql) to add notification history support.

CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id text NOT NULL,
  message text NOT NULL,
  type text DEFAULT 'admin_message',
  meta jsonb DEFAULT '{}'::jsonb,
  read boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Helpful index for lookups by student and unread status
CREATE INDEX IF NOT EXISTS idx_notifications_student_id ON public.notifications (student_id);
CREATE INDEX IF NOT EXISTS idx_notifications_student_unread ON public.notifications (student_id, read) WHERE (read = false);

-- Optional: grant minimal insert/select/update to an authenticated role (adjust role name as needed)
-- GRANT INSERT, SELECT, UPDATE ON public.notifications TO authenticated;

-- Example: insert a test notification
-- INSERT INTO public.notifications (student_id, message, type) VALUES ('S12345', 'Test notification from admin', 'admin_message');

-- Note: If your Supabase project doesn't have the extension for gen_random_uuid(), enable pgcrypto or use uuid_generate_v4():
-- CREATE EXTENSION IF NOT EXISTS pgcrypto;
-- or
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- End of migration
