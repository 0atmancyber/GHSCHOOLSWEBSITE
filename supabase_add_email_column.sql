-- Add email column to students table if it doesn't exist
ALTER TABLE students ADD COLUMN IF NOT EXISTS email VARCHAR(100);

-- Create index on email if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_students_email ON students(email);

-- If you want to add email to an existing student record, use:
-- UPDATE students SET email = 'new_email@example.com' WHERE student_id = 'GHTS7099';
