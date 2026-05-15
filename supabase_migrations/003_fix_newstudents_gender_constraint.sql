-- Migration to document and potentially fix the newstudents gender constraint
-- The newstudents table has a CHECK constraint on the gender column
-- Error code 23514 indicates CHECK constraint violation
-- 
-- This migration documents the expected gender values:
-- - Single letters: 'M' (Male), 'F' (Female), 'O' (Other)
-- - Or full words: 'Male', 'Female', 'Other'
-- - Or lowercase: 'male', 'female', 'other'
--
-- If the constraint is too restrictive, uncomment and run the ALTER TABLE statement below

-- Option 1: If the constraint doesn't exist, create it
-- ALTER TABLE public.newstudents
-- ADD CONSTRAINT newstudents_gender_check 
-- CHECK (gender IN ('M', 'F', 'O', 'Male', 'Female', 'Other', 'male', 'female', 'other'));

-- Option 2: If it exists and is too restrictive, drop and recreate it
-- ALTER TABLE public.newstudents
-- DROP CONSTRAINT IF EXISTS newstudents_gender_check;
-- 
-- ALTER TABLE public.newstudents
-- ADD CONSTRAINT newstudents_gender_check 
-- CHECK (gender IN ('M', 'F', 'O', 'Male', 'Female', 'Other', 'male', 'female', 'other'));

-- Note: The application code sends gender as single letters (M, F, O)
-- based on mapping from form dropdown values (Male, Female, Other)
