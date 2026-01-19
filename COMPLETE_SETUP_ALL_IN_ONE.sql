-- ============================================================================
-- COMPLETE SETUP: CREATE TABLE + INSERT DATA + SET UP ELIGIBILITY
-- Run this COMPLETE script in order (all at once)
-- Copy and paste into your Supabase SQL Editor
-- ============================================================================

-- ============================================================================
-- STEP 1: CREATE PAYMENTS TABLE
-- ============================================================================

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
  updated_at timestamptz DEFAULT now(),
  required_amount numeric DEFAULT 0
);

-- Add foreign key constraint to students table
ALTER TABLE payments 
ADD CONSTRAINT fk_payments_students 
FOREIGN KEY (student_id) 
REFERENCES students(student_id) 
ON DELETE RESTRICT 
ON UPDATE CASCADE;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_payments_student_id ON payments(student_id);
CREATE INDEX IF NOT EXISTS idx_payments_payment_date ON payments(payment_date DESC);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_fee_type ON payments(fee_type);
CREATE INDEX IF NOT EXISTS idx_payments_created_at ON payments(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payments_student_status ON payments(student_id, status);

-- ============================================================================
-- STEP 2: INSERT SAMPLE PAYMENT DATA
-- ============================================================================

INSERT INTO payments (
  student_id,
  student_name,
  student_email,
  department,
  level,
  amount,
  fee_type,
  payment_coverage,
  coverage_percent,
  transaction_ref,
  receipt_number,
  payment_date,
  status,
  source_table,
  reference_code,
  phone,
  required_amount
) VALUES
  ('STU001', 'Ama Mensah', 'ama.mensah@university.edu.gh', 'Computer Science', 'Level 200', 1500.00, 'Tuition', 'Partial', 50, 'TXN-20250101-001', 'RCPT-001', '2025-01-01 10:15:00+00', 'successful', 'momo_payments', 'REF-CS-001', '0241234567', 2500),
  ('STU002', 'Kwame Boateng', 'kwame.boateng@university.edu.gh', 'Business Admin', 'Level 300', 3000.00, 'Tuition', 'Full', 100, 'TXN-20250103-002', 'RCPT-002', '2025-01-03 14:40:00+00', 'successful', 'card_payments', 'REF-BA-002', '0559876543', 3000),
  ('STU003', 'Efua Asare', 'efua.asare@university.edu.gh', 'Nursing', 'Level 100', 500.00, 'Registration', 'Partial', 25, 'TXN-20250105-003', 'RCPT-003', '2025-01-05 09:05:00+00', 'pending', 'momo_payments', 'REF-NU-003', '0204567890', 2000),
  ('STU004', 'Kofi Adu', 'kofi.adu@university.edu.gh', 'Engineering', 'Level 400', 4500.00, 'Graduation', 'Full', 100, 'TXN-20250106-004', 'RCPT-004', '2025-01-06 16:30:00+00', 'failed', 'bank_transfer', 'REF-EN-004', '0263344556', 3500),
  ('STU005', 'Yaa Owusu', 'yaa.owusu@university.edu.gh', 'Economics', 'Level 200', 1200.00, 'Library', 'Partial', 40, 'TXN-20250107-005', 'RCPT-005', '2025-01-07 11:50:00+00', 'successful', 'momo_payments', 'REF-EC-005', '0507788991', 2500);

-- ============================================================================
-- STEP 3: CREATE VIEWS FOR PAYMENT TRACKING WITH ELIGIBILITY
-- ============================================================================

-- Drop old views if they exist
DROP VIEW IF EXISTS student_payment_eligibility CASCADE;
DROP VIEW IF EXISTS student_payment_details CASCADE;
DROP VIEW IF EXISTS payments_with_student_info CASCADE;

-- View 1: Payments with student information
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

-- View 2: Student Payment Eligibility (respects required amounts)
CREATE OR REPLACE VIEW student_payment_eligibility AS
SELECT 
  s.student_id,
  s.first_name || ' ' || COALESCE(s.middle_name || ' ', '') || s.surname AS full_name,
  s.email,
  s.phone_number,
  s.department,
  s.level,
  -- Required amount for this level
  CASE 
    WHEN s.level = 'Level 100' THEN 2000
    WHEN s.level = 'Level 200' THEN 2500
    WHEN s.level = 'Level 300' THEN 3000
    WHEN s.level = 'Level 400' THEN 3500
    ELSE 2500
  END as required_amount,
  -- Total paid (only successful payments)
  COALESCE(SUM(CASE WHEN p.status IN ('approved', 'completed', 'success', 'successful') THEN p.amount ELSE 0 END), 0) as total_paid,
  -- Calculate percentage paid
  ROUND(
    (COALESCE(SUM(CASE WHEN p.status IN ('approved', 'completed', 'success', 'successful') THEN p.amount ELSE 0 END), 0) / 
    CASE 
      WHEN s.level = 'Level 100' THEN 2000
      WHEN s.level = 'Level 200' THEN 2500
      WHEN s.level = 'Level 300' THEN 3000
      WHEN s.level = 'Level 400' THEN 3500
      ELSE 2500
    END) * 100, 2
  ) as percentage_paid,
  -- Amount still owing for 100% payment
  CASE 
    WHEN s.level = 'Level 100' THEN 2000
    WHEN s.level = 'Level 200' THEN 2500
    WHEN s.level = 'Level 300' THEN 3000
    WHEN s.level = 'Level 400' THEN 3500
    ELSE 2500
  END - COALESCE(SUM(CASE WHEN p.status IN ('approved', 'completed', 'success', 'successful') THEN p.amount ELSE 0 END), 0) as amount_owing,
  -- 80% threshold needed for eligibility
  ROUND((CASE 
    WHEN s.level = 'Level 100' THEN 2000
    WHEN s.level = 'Level 200' THEN 2500
    WHEN s.level = 'Level 300' THEN 3000
    WHEN s.level = 'Level 400' THEN 3500
    ELSE 2500
  END) * 0.80, 2) as amount_needed_for_80_percent,
  -- Eligibility status (80% paid = eligible)
  COALESCE(SUM(CASE WHEN p.status IN ('approved', 'completed', 'success', 'successful') THEN p.amount ELSE 0 END), 0) >= (
    CASE 
      WHEN s.level = 'Level 100' THEN 2000 * 0.80
      WHEN s.level = 'Level 200' THEN 2500 * 0.80
      WHEN s.level = 'Level 300' THEN 3000 * 0.80
      WHEN s.level = 'Level 400' THEN 3500 * 0.80
      ELSE 2500 * 0.80
    END
  ) as is_eligible_to_register,
  -- Status message
  CASE 
    WHEN COALESCE(SUM(CASE WHEN p.status IN ('approved', 'completed', 'success', 'successful') THEN p.amount ELSE 0 END), 0) >= (
      CASE 
        WHEN s.level = 'Level 100' THEN 2000 * 0.80
        WHEN s.level = 'Level 200' THEN 2500 * 0.80
        WHEN s.level = 'Level 300' THEN 3000 * 0.80
        WHEN s.level = 'Level 400' THEN 3500 * 0.80
        ELSE 2500 * 0.80
      END
    ) THEN '✓ ELIGIBLE TO REGISTER'
    ELSE '✗ NOT ELIGIBLE - MORE PAYMENT REQUIRED'
  END as eligibility_status,
  COALESCE(MAX(p.payment_date), s.created_at) as last_payment_date
FROM students s
LEFT JOIN payments p ON s.student_id = p.student_id
GROUP BY s.id, s.student_id, s.first_name, s.middle_name, s.surname, s.email, s.phone_number, s.department, s.level, s.created_at;

-- View 3: Detailed payment breakdown by student
CREATE OR REPLACE VIEW student_payment_details AS
SELECT 
  s.student_id,
  s.first_name || ' ' || COALESCE(s.middle_name || ' ', '') || s.surname AS full_name,
  s.email,
  s.department,
  s.level,
  -- Required amount based on level
  CASE 
    WHEN s.level = 'Level 100' THEN 2000
    WHEN s.level = 'Level 200' THEN 2500
    WHEN s.level = 'Level 300' THEN 3000
    WHEN s.level = 'Level 400' THEN 3500
    ELSE 2500
  END as total_required,
  COUNT(p.id) as total_payment_records,
  COUNT(CASE WHEN p.status IN ('approved', 'completed', 'success', 'successful') THEN 1 END) as successful_payments,
  COUNT(CASE WHEN p.status = 'failed' THEN 1 END) as failed_payments,
  COUNT(CASE WHEN p.status = 'pending' THEN 1 END) as pending_payments,
  COALESCE(SUM(CASE WHEN p.status IN ('approved', 'completed', 'success', 'successful') THEN p.amount ELSE 0 END), 0) as total_paid,
  COALESCE(SUM(CASE WHEN p.status = 'failed' THEN p.amount ELSE 0 END), 0) as total_failed,
  COALESCE(SUM(CASE WHEN p.status = 'pending' THEN p.amount ELSE 0 END), 0) as total_pending,
  ROUND((CASE 
    WHEN s.level = 'Level 100' THEN 2000
    WHEN s.level = 'Level 200' THEN 2500
    WHEN s.level = 'Level 300' THEN 3000
    WHEN s.level = 'Level 400' THEN 3500
    ELSE 2500
  END) * 0.80, 2) as amount_needed_for_80_percent_eligibility,
  GREATEST(0, ROUND((CASE 
    WHEN s.level = 'Level 100' THEN 2000
    WHEN s.level = 'Level 200' THEN 2500
    WHEN s.level = 'Level 300' THEN 3000
    WHEN s.level = 'Level 400' THEN 3500
    ELSE 2500
  END) * 0.80, 2) - COALESCE(SUM(CASE WHEN p.status IN ('approved', 'completed', 'success', 'successful') THEN p.amount ELSE 0 END), 0)) as amount_still_owing_for_eligibility
FROM students s
LEFT JOIN payments p ON s.student_id = p.student_id
GROUP BY s.id, s.student_id, s.first_name, s.middle_name, s.surname, s.email, s.department, s.level;

-- ============================================================================
-- VERIFICATION - RUN THESE TO CHECK YOUR DATA
-- ============================================================================

-- Check 1: All payments inserted
SELECT COUNT(*) as total_payments FROM payments;

-- Check 2: Student eligibility status
SELECT * FROM student_payment_eligibility ORDER BY is_eligible_to_register DESC, last_payment_date DESC;

-- Check 3: Payment details by student
SELECT * FROM student_payment_details ORDER BY department, level;

-- Check 4: All payment records
SELECT student_id, student_name, department, level, amount, fee_type, status, payment_date FROM payments_with_student_info ORDER BY payment_date DESC;
