-- Migration: create level100_registrations table
-- Adds columns for student level, student course, and registration status

CREATE TABLE IF NOT EXISTS level100_registrations (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id text,
  student_name text,
  student_level text,
  student_course text,
  contact_phone text,
  contact_whatsapp text,
  contact_email text,
  school text,
  program text,
  registration_status text DEFAULT 'pending',
  courses jsonb,
  created_at timestamptz DEFAULT now()
);

-- Indexes for common lookups
CREATE INDEX IF NOT EXISTS idx_level100_registrations_student_id ON level100_registrations (student_id);
CREATE INDEX IF NOT EXISTS idx_level100_registrations_created_at ON level100_registrations (created_at DESC);
