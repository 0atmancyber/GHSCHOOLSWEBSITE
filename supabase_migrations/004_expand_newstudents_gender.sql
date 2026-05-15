-- Migration: Expand/replace gender constraint on newstudents
-- Drops existing newstudents_gender_check (if present) and recreates it to accept full words and common codes
-- Run this in Supabase SQL editor (Project -> SQL) or via psql

BEGIN;

ALTER TABLE IF EXISTS public.newstudents
  DROP CONSTRAINT IF EXISTS newstudents_gender_check;

ALTER TABLE IF EXISTS public.newstudents
  ADD CONSTRAINT newstudents_gender_check
  CHECK (
    gender IS NULL OR
    gender IN (
      'M','F','O',           -- single-letter codes
      'Male','Female','Other',
      'male','female','other'
    )
  );

COMMIT;

-- Verification query (run after migration):
-- SELECT column_name, data_type, character_maximum_length
-- FROM information_schema.columns
-- WHERE table_name = 'newstudents' AND column_name = 'gender';

-- If the gender column is defined as character varying(2), consider altering it to a larger length:
-- ALTER TABLE public.newstudents ALTER COLUMN gender TYPE varchar(16);

-- If you alter the column type, run the verification query above again to confirm.
