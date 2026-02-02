-- ALTERNATIVE: Foreign Key with ON DELETE SET NULL
-- Use this if you want to KEEP payment records but clear the student reference
-- (Choose ONE of these two approaches, not both)

-- Drop the existing constraint
ALTER TABLE payments 
DROP CONSTRAINT IF EXISTS fk_payments_students CASCADE;

-- Add the foreign key with ON DELETE SET NULL
-- This means: when a student is deleted, their payment records remain but student_id becomes NULL
ALTER TABLE payments
ADD CONSTRAINT fk_payments_students 
FOREIGN KEY (student_id) 
REFERENCES student_master_db(student_id) 
ON DELETE SET NULL 
ON UPDATE CASCADE;

-- Note: If using this approach, you may want to allow NULL values in the student_id column:
-- ALTER TABLE payments ALTER COLUMN student_id DROP NOT NULL;
