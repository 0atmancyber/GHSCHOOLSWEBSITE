-- ============================================================================
-- COMPLETE PAYMENTS TABLE UPDATE FOR NEW STUDENTS INTEGRATION
-- Copy and paste this entire script into your Supabase SQL Editor
-- ============================================================================

-- Step 1: Add missing columns if they don't exist
ALTER TABLE payments ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- Step 2: Modify existing columns to ensure proper types (if needed)
-- ALTER TABLE payments ALTER COLUMN student_id SET DATA TYPE varchar(50);
-- ALTER TABLE payments ALTER COLUMN student_name SET DATA TYPE text;
-- ALTER TABLE payments ALTER COLUMN student_email SET DATA TYPE text;
-- ALTER TABLE payments ALTER COLUMN department SET DATA TYPE text;
-- ALTER TABLE payments ALTER COLUMN level SET DATA TYPE text;
-- ALTER TABLE payments ALTER COLUMN amount SET DATA TYPE numeric;
-- ALTER TABLE payments ALTER COLUMN fee_type SET DATA TYPE text;
-- ALTER TABLE payments ALTER COLUMN payment_coverage SET DATA TYPE text;
-- ALTER TABLE payments ALTER COLUMN coverage_percent SET DATA TYPE int4;
-- ALTER TABLE payments ALTER COLUMN transaction_ref SET DATA TYPE text;
-- ALTER TABLE payments ALTER COLUMN receipt_number SET DATA TYPE text;
-- ALTER TABLE payments ALTER COLUMN payment_date SET DATA TYPE timestamptz;
-- ALTER TABLE payments ALTER COLUMN status SET DATA TYPE text;
-- ALTER TABLE payments ALTER COLUMN source_table SET DATA TYPE text;
-- ALTER TABLE payments ALTER COLUMN created_at SET DATA TYPE timestamptz;
-- ALTER TABLE payments ALTER COLUMN reference_code SET DATA TYPE text;
-- ALTER TABLE payments ALTER COLUMN phone SET DATA TYPE varchar;

-- Step 3: Drop existing foreign key if it exists (to avoid conflicts)
ALTER TABLE payments DROP CONSTRAINT IF EXISTS fk_payments_students CASCADE;

-- Step 4: Add foreign key constraint to link with students table
ALTER TABLE payments 
ADD CONSTRAINT fk_payments_students 
FOREIGN KEY (student_id) 
REFERENCES students(student_id) 
ON DELETE RESTRICT 
ON UPDATE CASCADE;

-- Step 5: Create indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_payments_student_id ON payments(student_id);
CREATE INDEX IF NOT EXISTS idx_payments_payment_date ON payments(payment_date DESC);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_fee_type ON payments(fee_type);
CREATE INDEX IF NOT EXISTS idx_payments_created_at ON payments(created_at DESC);

-- Step 6: Create composite index for common queries
CREATE INDEX IF NOT EXISTS idx_payments_student_status ON payments(student_id, status);

-- Step 7: Drop old views if they exist (to avoid conflicts)
DROP VIEW IF EXISTS payments_summary_by_student CASCADE;
DROP VIEW IF EXISTS payments_with_student_info CASCADE;

-- Step 8: Create view to join payments with current student information
-- This gives you the latest student data along with payment records
CREATE OR REPLACE VIEW payments_with_student_info AS
SELECT 
  p.id,
  p.student_id,
  s.first_name,
  s.middle_name,
  s.surname,
  COALESCE(s.first_name || ' ' || COALESCE(s.middle_name || ' ', '') || s.surname, p.student_name) AS full_name,
  s.email AS current_email,
  p.student_email AS payment_record_email,
  s.phone_number,
  s.whatsapp_number,
  p.phone AS payment_phone,
  s.department AS current_department,
  p.department AS payment_record_department,
  s.level AS current_level,
  p.level AS payment_record_level,
  p.amount,
  p.fee_type,
  p.payment_coverage,
  p.coverage_percent,
  p.transaction_ref,
  p.receipt_number,
  p.payment_date,
  p.status,
  p.source_table,
  p.source_payload,
  p.created_at,
  p.updated_at,
  p.reference_code
FROM payments p
LEFT JOIN students s ON p.student_id = s.student_id
ORDER BY p.payment_date DESC;

-- Step 9: Create a view for payments summary by student
-- Use this to see payment statistics for each student
CREATE OR REPLACE VIEW payments_summary_by_student AS
SELECT 
  s.student_id,
  s.first_name,
  s.middle_name,
  s.surname,
  s.first_name || ' ' || COALESCE(s.middle_name || ' ', '') || s.surname AS full_name,
  s.email,
  s.phone_number,
  s.department,
  s.level,
  COUNT(p.id) as total_payments,
  COUNT(CASE WHEN p.status IN ('approved', 'completed', 'success', 'paid') THEN 1 END) as approved_payments,
  COUNT(CASE WHEN p.status = 'pending' THEN 1 END) as pending_payments,
  COUNT(CASE WHEN p.status = 'failed' THEN 1 END) as failed_payments,
  COALESCE(SUM(CASE WHEN p.status IN ('approved', 'completed', 'success', 'paid') THEN p.amount ELSE 0 END), 0) as total_amount_paid,
  COALESCE(MAX(p.payment_date), NULL) as last_payment_date
FROM students s
LEFT JOIN payments p ON s.student_id = p.student_id
GROUP BY s.id, s.student_id, s.first_name, s.middle_name, s.surname, s.email, s.phone_number, s.department, s.level;

-- Step 10: Create a view for payment eligibility status
-- Shows which students have paid enough to be eligible for registration
CREATE OR REPLACE VIEW student_payment_eligibility AS
SELECT 
  s.student_id,
  s.first_name || ' ' || COALESCE(s.middle_name || ' ', '') || s.surname AS full_name,
  s.email,
  s.department,
  s.level,
  COALESCE(SUM(CASE WHEN p.status IN ('approved', 'completed', 'success', 'paid') THEN p.amount ELSE 0 END), 0) as total_paid,
  COALESCE(SUM(CASE WHEN p.status IN ('approved', 'completed', 'success', 'paid') THEN p.amount ELSE 0 END), 0) >= 5000 as is_eligible_80_percent,
  COALESCE(MAX(p.payment_date), s.created_at) as last_payment_date
FROM students s
LEFT JOIN payments p ON s.student_id = p.student_id
GROUP BY s.id, s.student_id, s.first_name, s.middle_name, s.surname, s.email, s.department, s.level, s.created_at;

-- Step 11: Update existing payment records with current timestamp
UPDATE payments SET updated_at = CURRENT_TIMESTAMP WHERE updated_at IS NULL;

-- Step 12: Verify the setup
-- Run these queries to verify everything is working:

-- Check payments table structure
-- SELECT column_name, data_type, is_nullable 
-- FROM information_schema.columns 
-- WHERE table_name = 'payments' 
-- ORDER BY ordinal_position;

-- Check indexes
-- SELECT indexname FROM pg_indexes WHERE tablename = 'payments';

-- Check views exist
-- SELECT table_name FROM information_schema.views 
-- WHERE table_schema = 'public' AND table_name LIKE 'payments%';

-- Sample query: Get all payments for a student with their current info
-- SELECT * FROM payments_with_student_info 
-- WHERE student_id = 'GHTS7099'
-- ORDER BY payment_date DESC;

-- Sample query: Get payment summary for all students
-- SELECT * FROM payments_summary_by_student 
-- WHERE department = 'Technology'
-- ORDER BY last_payment_date DESC;

-- Sample query: Check eligibility status
-- SELECT * FROM student_payment_eligibility 
-- WHERE department = 'Technology';

-- ============================================================================
-- NOTES:
-- ============================================================================
-- 1. The foreign key constraint links payments to students table
-- 2. ON DELETE RESTRICT prevents accidental student deletion if they have payments
-- 3. ON UPDATE CASCADE ensures student_id updates cascade to payments
-- 4. Indexes improve query performance for common operations
-- 5. Views provide consistent data retrieval with student info
-- 6. Historical payment data is preserved (student_name, student_email, etc.)
-- 7. The views use LEFT JOIN to show students even if they have no payments
-- 8. All timestamps are in UTC (timestamptz)

-- ============================================================================
-- IF YOU GET CONSTRAINT ERRORS:
-- ============================================================================
-- If you get "insert or update on table 'payments' violates foreign key constraint"
-- it means there are payment records with student_id values that don't exist in students table.
-- 
-- To find mismatched records, run:
-- SELECT DISTINCT p.student_id 
-- FROM payments p 
-- WHERE NOT EXISTS (SELECT 1 FROM students s WHERE s.student_id = p.student_id);
--
-- To fix: Either add the missing students or delete the orphaned payment records:
-- DELETE FROM payments 
-- WHERE student_id NOT IN (SELECT student_id FROM students);
