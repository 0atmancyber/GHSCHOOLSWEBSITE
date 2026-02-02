-- FIX FOREIGN KEY CONSTRAINT for payments table
-- RUN THIS AFTER the student_master_db table has been created successfully
-- This allows proper deletion behavior when students are deleted

-- Step 1: Drop the existing foreign key constraint (if it exists)
ALTER TABLE payments 
DROP CONSTRAINT IF EXISTS fk_payments_students CASCADE;

-- Step 2: Add the foreign key constraint with ON DELETE CASCADE
-- This means: when a student is deleted, all their payment records will also be deleted
ALTER TABLE payments
ADD CONSTRAINT fk_payments_students 
FOREIGN KEY (student_id) 
REFERENCES student_master_db(student_id) 
ON DELETE CASCADE 
ON UPDATE CASCADE;

-- Done! Students can now be deleted safely.
