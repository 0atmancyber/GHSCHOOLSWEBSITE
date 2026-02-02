-- Update payments table to respect the new student_master_db table structure
-- This migration keeps historical data but aligns foreign key references

-- Step 1: Add updated_at column if it doesn't exist
ALTER TABLE payments ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- Step 2: Add foreign key constraint to student_master_db table (if not exists)
ALTER TABLE payments 
ADD CONSTRAINT fk_payments_students 
FOREIGN KEY (student_id) 
REFERENCES student_master_db(student_id) 
ON DELETE RESTRICT 
ON UPDATE CASCADE;

-- Step 3: Create an index on student_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_payments_student_id ON payments(student_id);

-- Step 4: Create an index on payment_date for filtering by date range
CREATE INDEX IF NOT EXISTS idx_payments_payment_date ON payments(payment_date);

-- Step 5: Create an index on status for filtering by status
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);

-- Step 6: Create a view to join payments with current student information
-- This allows you to always get the latest student data even if payment records have old data
CREATE OR REPLACE VIEW payments_with_student_info AS
SELECT 
  p.id,
  p.student_id,
  s.first_name,
  s.middle_name,
  s.surname,
  s.email,
  s.phone_number_1,
  s.whatsapp,
  s.department,
  s.level,
  p.amount,
  p.fee_type,
  p.payment_coverage,
  p.coverage_percent,
  p.transaction_ref,
  p.receipt_number,
  p.payment_date,
  p.status,
  p.source_table,
  p.created_at,
  p.updated_at,
  p.reference_code
FROM payments p
LEFT JOIN student_master_db s ON p.student_id = s.student_id
ORDER BY p.payment_date DESC;

-- Step 7: Create a view for payments summary by student
CREATE OR REPLACE VIEW payments_summary_by_student AS
SELECT 
  s.student_id,
  s.first_name || ' ' || COALESCE(s.middle_name || ' ', '') || s.surname AS full_name,
  s.email,
  s.department,
  s.level,
  COUNT(p.id) as total_payments,
  COALESCE(SUM(p.amount), 0) as total_amount_paid,
  COUNT(CASE WHEN p.status = 'completed' THEN 1 END) as completed_payments,
  COUNT(CASE WHEN p.status = 'pending' THEN 1 END) as pending_payments,
  MAX(p.payment_date) as last_payment_date
FROM student_master_db s
LEFT JOIN payments p ON s.student_id = p.student_id
GROUP BY s.id, s.student_id, s.first_name, s.middle_name, s.surname, s.email, s.department, s.level;

-- Step 8: Verify the payments table structure
-- Run this query to see your current payments table structure
-- SELECT column_name, data_type, is_nullable 
-- FROM information_schema.columns 
-- WHERE table_name = 'payments' 
-- ORDER BY ordinal_position;

-- Notes:
-- - The payments table now respects the student_master_db table with proper FK relationships
-- - Use the payments_with_student_info view to get complete student data with payments
-- - Historical data in student_name, student_email, department, level columns is preserved
-- - New queries should fetch from student_master_db table rather than storing in payments table
-- - This reduces data redundancy and ensures data consistency
