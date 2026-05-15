-- admin_users_setup.sql
-- Create the admin_users table (includes cashier and admissions roles)

-- Create table if not exists
CREATE TABLE IF NOT EXISTS public.admin_users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username      text NOT NULL UNIQUE,
  full_name     text,
  role          text NOT NULL CHECK (role IN ('superadmin','finance','academics','registrar','cashier','admissions')),
  password_hash text NOT NULL,   -- store plain text OR sha-256 hex of password
  is_active     boolean NOT NULL DEFAULT true,
  last_login    timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- If the table already existed with a narrower CHECK constraint, replace it safely
ALTER TABLE public.admin_users
  DROP CONSTRAINT IF EXISTS admin_users_role_check;
ALTER TABLE public.admin_users
  ADD CONSTRAINT admin_users_role_check CHECK (role IN ('superadmin','finance','academics','registrar','cashier','admissions'));

ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;

-- Create or replace policy in a Postgres-compatible way
DROP POLICY IF EXISTS "Allow login lookup" ON public.admin_users;
CREATE POLICY "Allow login lookup"
  ON public.admin_users
  FOR SELECT
  USING (true);

-- Seed the default admin accounts
-- Passwords below are stored as plain text to match the application's current login behavior.
-- Replace with SHA-256 hex digests for production use.
INSERT INTO public.admin_users (username, full_name, role, password_hash) VALUES
  ('superadmin', 'Super Administrator', 'superadmin', 'GHSchools@SA2025'),
  ('finance',    'Finance Officer',     'finance',    'GHSchools@Fin2025'),
  ('academics',  'Academic Staff',      'academics',  'GHSchools@Acad2025'),
  ('registrar',  'Registrar',           'registrar',  'GHSchools@Reg2025'),
  ('cashier',    'Cashier User',        'cashier',    'Cashier@2026'),
  ('admissions', 'Admissions Officer',  'admissions', 'Admissions@2026')
ON CONFLICT (username) DO NOTHING;

-- NOTES:
-- 1) The application supports storing either plain-text passwords or SHA-256 hex digests
--    in the `password_hash` column. For security, compute the SHA-256 digest and
--    replace the plain passwords with the hex values before deploying to production.
--    Example (linux/mac): echo -n 'Cashier@2026' | sha256sum
-- 2) After running this script in Supabase, you will be able to log in using the
--    usernames above and selecting the matching role from the login card.
-- 3) Consider disabling the "Allow login lookup" policy for anon after provisioning
--    and implement a secure auth flow using Supabase Auth for production.
