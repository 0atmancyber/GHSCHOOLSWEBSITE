-- ============================================================================
-- COMPLETE PAYMENTS TABLE - COPY AND PASTE
-- For Supabase SQL Editor
-- ============================================================================

-- If you need to recreate the table from scratch, use this:
-- WARNING: This will DROP the existing table and all data!
-- Only use this if you have backed up your data or are starting fresh

-- DROP TABLE IF EXISTS payments CASCADE;

-- CREATE TABLE payments (
--   id bigserial PRIMARY KEY,
--   student_id varchar(50) NOT NULL,
--   student_name text,
--   student_email text,
--   department text,
--   level text,
--   amount numeric NOT NULL DEFAULT 0,
--   fee_type text,
--   payment_coverage text,
--   coverage_percent int4,
--   transaction_ref text,
--   receipt_number text,
--   payment_date timestamptz,
--   status text,
--   source_table text,
--   source_payload jsonb,
--   created_at timestamptz DEFAULT now(),
--   reference_code text,
--   phone varchar,
--   updated_at timestamptz DEFAULT now(),
--   CONSTRAINT fk_payments_students FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE RESTRICT ON UPDATE CASCADE
-- );

-- ============================================================================
-- IF YOU ALREADY HAVE THE TABLE, RUN THIS TO UPDATE IT:
-- ============================================================================

-- Step 1: Add missing columns if they don't exist
ALTER TABLE payments ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- Step 2: Drop existing foreign key if it exists (to avoid conflicts)
ALTER TABLE payments DROP CONSTRAINT IF EXISTS fk_payments_students CASCADE;

-- Step 3: Add foreign key constraint to link with students table
ALTER TABLE payments 
ADD CONSTRAINT fk_payments_students 
FOREIGN KEY (student_id) 
REFERENCES students(student_id) 
ON DELETE RESTRICT 
ON UPDATE CASCADE;

-- Step 4: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_payments_student_id ON payments(student_id);
CREATE INDEX IF NOT EXISTS idx_payments_payment_date ON payments(payment_date DESC);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_fee_type ON payments(fee_type);
CREATE INDEX IF NOT EXISTS idx_payments_created_at ON payments(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payments_student_status ON payments(student_id, status);

-- Step 5: Drop old views if they exist
DROP VIEW IF EXISTS payments_summary_by_student CASCADE;
DROP VIEW IF EXISTS payments_with_student_info CASCADE;
DROP VIEW IF EXISTS student_payment_eligibility CASCADE;

-- Step 6: Create view - payments with current student information
CREATE OR REPLACE VIEW payments_with_student_info AS
SELECT 
  p.id,
  p.student_id,
  s.first_name,
  s.middle_name,
  s.surname,
  s.first_name || ' ' || COALESCE(s.middle_name || ' ', '') || s.surname AS full_name,
  s.email,
  s.phone_number,
  s.whatsapp_number,
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
LEFT JOIN students s ON p.student_id = s.student_id
ORDER BY p.payment_date DESC;

-- Step 7: Create view - payment summary by student
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

-- Step 8: Create view - student payment eligibility
CREATE OR REPLACE VIEW student_payment_eligibility AS
SELECT 
  s.student_id,
  s.first_name || ' ' || COALESCE(s.middle_name || ' ', '') || s.surname AS full_name,
  s.email,
  s.phone_number,
  s.department,
  s.level,
  COALESCE(SUM(CASE WHEN p.status IN ('approved', 'completed', 'success', 'paid') THEN p.amount ELSE 0 END), 0) as total_paid,
  COALESCE(SUM(CASE WHEN p.status IN ('approved', 'completed', 'success', 'paid') THEN p.amount ELSE 0 END), 0) >= 5000 as is_eligible_80_percent,
  COALESCE(MAX(p.payment_date), s.created_at) as last_payment_date
FROM students s
LEFT JOIN payments p ON s.student_id = p.student_id
GROUP BY s.id, s.student_id, s.first_name, s.middle_name, s.surname, s.email, s.phone_number, s.department, s.level, s.created_at;

-- Step 9: Update existing payment records with current timestamp
UPDATE payments SET updated_at = CURRENT_TIMESTAMP WHERE updated_at IS NULL;

-- ============================================================================
-- VERIFY THE SETUP
-- ============================================================================

-- Uncomment and run these queries to verify:

-- Check table structure
-- SELECT column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns 
-- WHERE table_name = 'payments' 
-- ORDER BY ordinal_position;

-- Check all indexes on payments table
-- SELECT indexname, indexdef 
-- FROM pg_indexes 
-- WHERE tablename = 'payments'
-- ORDER BY indexname;

-- Check all views
-- SELECT table_name 
-- FROM information_schema.views 
-- WHERE table_schema = 'public' AND table_name LIKE '%payment%'
-- ORDER BY table_name;

-- Check foreign keys
-- SELECT constraint_name, table_name, column_name, foreign_table_name, foreign_column_name
-- FROM information_schema.key_column_usage
-- WHERE table_name = 'payments' AND foreign_table_name IS NOT NULL;

-- ============================================================================
-- EXAMPLE QUERIES
-- ============================================================================

-- Get all payments for a specific student
-- SELECT * FROM payments_with_student_info 
-- WHERE student_id = 'GHTS7099'
-- ORDER BY payment_date DESC;

-- Get payment summary for all students in Technology department
-- SELECT * FROM payments_summary_by_student 
-- WHERE department = 'Technology'
-- ORDER BY total_amount_paid DESC;

-- Get students eligible to register (paid 80% or more)
-- SELECT * FROM student_payment_eligibility 
-- WHERE is_eligible_80_percent = true
-- ORDER BY last_payment_date DESC;

-- Get all payments with amounts greater than 1000
-- SELECT student_id, full_name, department, amount, payment_date, status 
-- FROM payments_with_student_info 
-- WHERE amount > 1000
-- ORDER BY payment_date DESC;

-- Get payment statistics by department
-- SELECT 
--   department,
--   COUNT(DISTINCT student_id) as total_students,
--   COUNT(DISTINCT CASE WHEN status IN ('approved', 'completed', 'success', 'paid') THEN student_id END) as students_with_payments,
--   SUM(CASE WHEN status IN ('approved', 'completed', 'success', 'paid') THEN amount ELSE 0 END) as total_collected
-- FROM payments_with_student_info
-- GROUP BY department
-- ORDER BY total_collected DESC;

-- ============================================================================
-- TROUBLESHOOTING
-- ============================================================================

-- If you get foreign key constraint error:
-- Run this to find payments with invalid student_id
-- SELECT DISTINCT p.student_id 
-- FROM payments p 
-- WHERE NOT EXISTS (SELECT 1 FROM students s WHERE s.student_id = p.student_id);

-- To delete orphaned payment records:
-- DELETE FROM payments 
-- WHERE student_id NOT IN (SELECT student_id FROM students);

-- ============================================================================
-- TABLE STRUCTURE SUMMARY
-- ============================================================================

-- PAYMENTS TABLE COLUMNS:
-- - id: bigserial PRIMARY KEY
-- - student_id: varchar(50) - Foreign key to students table
-- - student_name: text - Stored for audit trail
-- - student_email: text - Stored for audit trail
-- - department: text - Stored for audit trail
-- - level: text - Stored for audit trail
-- - amount: numeric - Payment amount
-- - fee_type: text - Type of fee
-- - payment_coverage: text - Coverage type (full, partial_80, etc)
-- - coverage_percent: int4 - Coverage percentage
-- - transaction_ref: text - Transaction reference
-- - receipt_number: text - Receipt number
-- - payment_date: timestamptz - Payment date
-- - status: text - Payment status (approved, completed, pending, failed)
-- - source_table: text - Source table
-- - source_payload: jsonb - Original payload
-- - created_at: timestamptz - Creation timestamp
-- - reference_code: text - Reference code
-- - phone: varchar - Phone number
-- - updated_at: timestamptz - Update timestamp

-- VIEWS CREATED:
-- 1. payments_with_student_info - Payments joined with current student data
-- 2. payments_summary_by_student - Payment statistics per student
-- 3. student_payment_eligibility - Eligibility status for each student

-- INDEXES CREATED:
-- 1. idx_payments_student_id - For student_id lookups
-- 2. idx_payments_payment_date - For date range queries
-- 3. idx_payments_status - For status filtering
-- 4. idx_payments_fee_type - For fee type filtering
-- 5. idx_payments_created_at - For creation date queries
-- 6. idx_payments_student_status - Composite index for common queries
