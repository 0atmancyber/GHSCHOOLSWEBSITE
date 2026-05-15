-- Payments / Transactions schema for GH Schools dashboard
-- Run this in your Supabase (Postgres) SQL editor

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Students table (if not already present)
CREATE TABLE IF NOT EXISTS students (
  id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  student_id text UNIQUE,
  admission_number text UNIQUE,
  full_name text,
  email text,
  phone text,
  program text,
  created_at timestamptz DEFAULT now()
);

-- Transactions / payments table
CREATE TABLE IF NOT EXISTS transactions (
  id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  student_id text REFERENCES students(student_id) ON DELETE SET NULL,
  description text,
  base_amount numeric(12,2),           -- original total fee
  amount numeric(12,2) NOT NULL,      -- amount paid
  percentage numeric(6,2),            -- percent of base_amount paid (eg 80.00)
  currency text DEFAULT 'GHS',
  method text,                         -- e.g. momo, bank, card
  status text,                         -- initiated, success, failed
  reference text UNIQUE,               -- payment provider reference
  metadata jsonb,                      -- raw provider/other metadata
  created_at timestamptz DEFAULT now()
);

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_transactions_student_id ON transactions(student_id);
CREATE INDEX IF NOT EXISTS idx_transactions_reference ON transactions(reference);

-- Example: simple view to show outstanding per student (optional)
CREATE OR REPLACE VIEW student_outstanding AS
SELECT s.student_id, s.full_name, COALESCE(t.base_amount,0) - COALESCE(sum(p.amount),0) AS outstanding
FROM students s
LEFT JOIN (
  SELECT DISTINCT ON (student_id) student_id, base_amount
  FROM transactions
  WHERE base_amount IS NOT NULL
  ORDER BY student_id, created_at DESC
) t ON t.student_id = s.student_id
LEFT JOIN transactions p ON p.student_id = s.student_id AND p.status = 'success'
GROUP BY s.student_id, s.full_name, t.base_amount;

-- Note: For production, implement server-side verification webhook to confirm payment
-- before marking status='success'. This schema assumes client will insert records,
-- but webhook-based verification is recommended.
