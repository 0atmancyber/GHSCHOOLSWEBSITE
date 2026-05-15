-- Migration: Ensure `public.newstudents` matches the application schema
-- This migration will:
-- 1. Create the table if it does not exist (with the full schema)
-- 2. Add any missing columns (safe, idempotent)
-- 3. Ensure a permissive gender constraint is present
-- 4. Create the reference generator trigger/function (idempotent)
-- Run this in psql or the Supabase SQL editor.

BEGIN;

-- ensure pgcrypto available for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- create table if missing (safe; will do nothing if table exists)
CREATE TABLE IF NOT EXISTS public.newstudents (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id character varying UNIQUE,
  first_name character varying,
  middle_name character varying,
  last_name character varying,
  dob date,
  gender character varying,
  phone_number character varying,
  email character varying,
  home_address character varying,
  nationality character varying,
  national_id_type character varying,
  national_id_number character varying,
  present_job character varying,
  language_spoken character varying,
  region character varying,
  current_residence character varying,
  hostel_preference character varying,
  any_medical character varying,
  medical_spec character varying,
  disability_spec character varying,
  heard_source character varying,
  heard_spec character varying,
  sponsor_name character varying,
  sponsor_relationship character varying,
  sponsor_occupation character varying,
  sponsor_address character varying,
  sponsor_phone character varying,
  school_name character varying,
  school_location character varying,
  school_year integer,
  school_qualification character varying,
  school_selected character varying,
  program_applying_for character varying,
  program_duration character varying,
  course_type character varying,
  passport_photo_url text,
  wassce_results_url text,
  english_grade character varying,
  mathematics_grade character varying,
  social_studies_grade character varying,
  integrated_science_grade character varying,
  wassce_core_score integer,
  wassce_core_average numeric,
  schools_attended jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  reference_code text,
  status text
);

-- Add any missing columns (idempotent)
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS student_id character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS first_name character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS middle_name character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS last_name character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS dob date;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS gender character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS phone_number character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS email character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS home_address character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS nationality character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS national_id_type character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS national_id_number character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS present_job character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS language_spoken character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS region character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS current_residence character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS hostel_preference character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS any_medical character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS medical_spec character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS disability_spec character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS heard_source character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS heard_spec character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS sponsor_name character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS sponsor_relationship character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS sponsor_occupation character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS sponsor_address character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS sponsor_phone character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS emergency_contact character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS signature_1 character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS declaration_date_1 date;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS signature_2 character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS declaration_date_2 date;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS school_name character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS school_location character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS school_year integer;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS school_qualification character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS school_selected character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS program_applying_for character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS program_duration character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS course_type character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS passport_photo_url text;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS wassce_results_url text;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS english_grade character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS mathematics_grade character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS social_studies_grade character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS integrated_science_grade character varying;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS wassce_core_score integer;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS wassce_core_average numeric;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS schools_attended jsonb;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS created_at timestamp with time zone DEFAULT now();
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT now();
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS reference_code text;
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS status text;

-- create unique index for student_id if missing (name-based, idempotent)
CREATE UNIQUE INDEX IF NOT EXISTS idx_newstudents_student_id_unique ON public.newstudents(student_id);

-- replace/ensure gender constraint to accept words and single-letter codes
ALTER TABLE IF EXISTS public.newstudents
  DROP CONSTRAINT IF EXISTS newstudents_gender_check;

ALTER TABLE IF EXISTS public.newstudents
  ADD CONSTRAINT newstudents_gender_check
  CHECK (
    gender IS NULL OR
    gender IN (
      'M','F','O',
      'Male','Female','Other',
      'male','female','other'
    )
  );

-- create or replace trigger function to generate reference_code and update timestamp
CREATE OR REPLACE FUNCTION public.generate_newstudent_reference()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.reference_code IS NULL OR NEW.reference_code = '' THEN
      NEW.reference_code := 'NS' || to_char(now() AT TIME ZONE 'utc', 'YYMMDD') || '-' || substr(md5(gen_random_uuid()::text), 1, 8);
    END IF;
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- attach trigger (idempotent)
DROP TRIGGER IF EXISTS trg_newstudents_generate_ref ON public.newstudents;
CREATE TRIGGER trg_newstudents_generate_ref
  BEFORE INSERT OR UPDATE ON public.newstudents
  FOR EACH ROW
  EXECUTE FUNCTION public.generate_newstudent_reference();

COMMIT;

-- Notes:
-- 1) This migration only adds missing columns and constraints. It avoids destructive operations.
-- 2) If you need to change existing column types (for example from varchar(2) to varchar(16)), run an ALTER TABLE ... ALTER COLUMN ... TYPE statement manually after reviewing existing data.
-- 3) Run this in the Supabase SQL editor or via psql with appropriate credentials.
