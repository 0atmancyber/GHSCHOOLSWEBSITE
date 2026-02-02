-- ============================================================================
-- CREATE PAYMENTS TABLE FROM SCRATCH
-- Run this FIRST before running the update script
-- Copy and paste into your Supabase SQL Editor
-- ============================================================================

-- Step 1: Create the payments table with all columns
CREATE TABLE IF NOT EXISTS payments (
  id bigserial PRIMARY KEY,
  student_id varchar(50) NOT NULL,
  student_name text,
  student_email text,
  department text,
  level text,
  amount numeric NOT NULL DEFAULT 0,
  fee_type text,
  payment_coverage text,
  coverage_percent int4,
  transaction_ref text,
  receipt_number text,
  payment_date timestamptz,
  status text,
  source_table text,
  source_payload jsonb,
  created_at timestamptz DEFAULT now(),
  reference_code text,
  phone varchar,
  updated_at timestamptz DEFAULT now()
);

-- Step 2: Add foreign key constraint to student_master_db table
ALTER TABLE payments 
ADD CONSTRAINT fk_payments_student_master_db 
FOREIGN KEY (student_id) 
REFERENCES student_master_db(student_id) 
ON DELETE RESTRICT 
ON UPDATE CASCADE;

-- Step 3: Create performance indexes
CREATE INDEX IF NOT EXISTS idx_payments_student_id ON payments(student_id);
CREATE INDEX IF NOT EXISTS idx_payments_payment_date ON payments(payment_date DESC);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_fee_type ON payments(fee_type);
CREATE INDEX IF NOT EXISTS idx_payments_created_at ON payments(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payments_student_status ON payments(student_id, status);

-- Step 4: Create view - payments with student info
CREATE OR REPLACE VIEW payments_with_student_info AS
SELECT 
  p.id,
  p.student_id,
  s.first_name,
  s.middle_name,
  s.surname,
  s.first_name || ' ' || COALESCE(s.middle_name || ' ', '') || s.surname AS full_name,
  s.email,
  s.phone_number_1,
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
LEFT JOIN student_master_db s ON p.student_id = s.student_id
ORDER BY p.payment_date DESC;

-- Step 5: Create view - payment summary by student
CREATE OR REPLACE VIEW payments_summary_by_student AS
SELECT 
  s.student_id,
  s.first_name,
  s.middle_name,
  s.surname,
  s.first_name || ' ' || COALESCE(s.middle_name || ' ', '') || s.surname AS full_name,
  s.email,
  s.phone_number_1,
  s.phone_number,
  s.department,
  s.level,
  COUNT(p.id) as total_payments,
  COUNT(CASE WHEN p.status IN ('approved', 'completed', 'success', 'paid') THEN 1 END) as approved_payments,
  COUNT(CASE WHEN p.status = 'pending' THEN 1 END) as pending_payments,
  COUNT(CASE WHEN p.status = 'failed' THEN 1 END) as failed_payments,
  COALESCE(SUM(CASE WHEN p.status IN ('approved', 'completed', 'success', 'paid') THEN p.amount ELSE 0 END), 0) as total_amount_paid,
  COALESCE(MAX(p.payment_date), NULL) as last_payment_date
FROM student_master_db s
LEFT JOIN payments p ON s.student_id = p.student_id
GROUP BY s.id, s.student_id, s.first_name, s.middle_name, s.surname, s.email, s.phone_number_1, s.phone_number, s.department, s.level; 

-- Step 6: Create view - student payment eligibility
CREATE OR REPLACE VIEW student_payment_eligibility AS
SELECT 
  s.student_id,
  s.first_name || ' ' || COALESCE(s.middle_name || ' ', '') || s.surname AS full_name,
  s.email,
  s.phone_number_1,
  s.phone_number,
  s.department,
  s.level,
  COALESCE(SUM(CASE WHEN p.status IN ('approved', 'completed', 'success', 'paid') THEN p.amount ELSE 0 END), 0) as total_paid,
  COALESCE(SUM(CASE WHEN p.status IN ('approved', 'completed', 'success', 'paid') THEN p.amount ELSE 0 END), 0) >= 5000 as is_eligible_80_percent,
  COALESCE(MAX(p.payment_date), s.created_at) as last_payment_date
FROM student_master_db s
LEFT JOIN payments p ON s.student_id = p.student_id
GROUP BY s.id, s.student_id, s.first_name, s.middle_name, s.surname, s.email, s.phone_number_1, s.phone_number, s.department, s.level, s.created_at; 

-- Done! The payments table is now created and ready to use.

-- ============================================================================
-- VERIFY SETUP (uncomment to test)
-- ============================================================================

-- Check table exists
-- SELECT * FROM information_schema.tables WHERE table_name = 'payments';

-- Check table structure
-- SELECT column_name, data_type, is_nullable 
-- FROM information_schema.columns 
-- WHERE table_name = 'payments' 
-- ORDER BY ordinal_position;

-- Check indexes
-- SELECT indexname FROM pg_indexes WHERE tablename = 'payments';

-- Check views
-- SELECT table_name FROM information_schema.views 
-- WHERE table_schema = 'public' AND table_name LIKE '%payment%';

-- ============================================================================
-- TABLE STRUCTURE
-- ============================================================================

-- PAYMENTS TABLE:
-- ├── id: bigserial (Primary Key)
-- ├── student_id: varchar(50) - Foreign Key to student_master_db table
-- ├── student_name: text - Student name snapshot
-- ├── student_email: text - Email snapshot
-- ├── department: text - Department snapshot
-- ├── level: text - Level snapshot
-- ├── amount: numeric - Payment amount
-- ├── fee_type: text - Type of fee
-- ├── payment_coverage: text - Coverage (full, partial_80, etc)
-- ├── coverage_percent: int4 - Coverage percentage
-- ├── transaction_ref: text - Transaction reference
-- ├── receipt_number: text - Receipt number
-- ├── payment_date: timestamptz - When payment was made
-- ├── status: text - Payment status
-- ├── source_table: text - Source table
-- ├── source_payload: jsonb - Original data
-- ├── created_at: timestamptz - Record creation
-- ├── reference_code: text - Reference code
-- ├── phone: varchar - Phone number
-- └── updated_at: timestamptz - Last update

-- INDEXES:
-- ├── idx_payments_student_id
-- ├── idx_payments_payment_date
-- ├── idx_payments_status
-- ├── idx_payments_fee_type
-- ├── idx_payments_created_at
-- └── idx_payments_student_status

-- VIEWS:
-- ├── payments_with_student_info
-- ├── payments_summary_by_student
-- └── student_payment_eligibility
