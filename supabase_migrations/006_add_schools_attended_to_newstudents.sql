-- Migration: add schools_attended jsonb column to newstudents
-- Run this migration in your database (psql or Supabase SQL editor)

ALTER TABLE IF EXISTS public.newstudents
  ADD COLUMN IF NOT EXISTS schools_attended jsonb;

-- Optionally add a GIN index for efficient querying:
-- CREATE INDEX IF NOT EXISTS idx_newstudents_schools_attended_gin ON public.newstudents USING gin (schools_attended);
