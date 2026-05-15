-- Migration: add is_admission_form flag and triggers for newstudents
-- Run this in your database (psql or Supabase SQL editor)

BEGIN;

-- add flag column
ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS is_admission_form boolean DEFAULT false;

-- create trigger function to generate reference_code and update updated_at
CREATE OR REPLACE FUNCTION public.generate_newstudent_reference()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  -- generate a human-friendly reference code on insert if not supplied
  IF TG_OP = 'INSERT' THEN
    IF NEW.reference_code IS NULL OR NEW.reference_code = '' THEN
      NEW.reference_code := 'NS' || to_char(now() AT TIME ZONE 'utc', 'YYMMDD') || '-' || substr(md5(gen_random_uuid()::text), 1, 8);
    END IF;
  END IF;

  -- always update updated_at timestamp
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- attach trigger (before insert or update)
DROP TRIGGER IF EXISTS trg_newstudents_generate_ref ON public.newstudents;
CREATE TRIGGER trg_newstudents_generate_ref
  BEFORE INSERT OR UPDATE ON public.newstudents
  FOR EACH ROW
  EXECUTE FUNCTION public.generate_newstudent_reference();

COMMIT;
