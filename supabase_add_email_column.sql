-- Add email column to student_master_db table if it doesn't exist
ALTER TABLE student_master_db ADD COLUMN IF NOT EXISTS email VARCHAR(100);

-- Create index on email if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_student_master_db_email ON student_master_db(email);

-- If you want to add email to an existing student record, use:
-- UPDATE students SET email = 'new_email@example.com' WHERE student_id = 'GHTS7099';
