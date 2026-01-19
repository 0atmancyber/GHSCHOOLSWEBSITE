-- ============================================================================
-- INSERT SAMPLE PAYMENTS DATA WITH REGISTRATION ELIGIBILITY TRACKING
-- Copy and paste into your Supabase SQL Editor
-- ============================================================================

-- Step 1: Add required_amount column to track required fees per student
ALTER TABLE payments ADD COLUMN IF NOT EXISTS required_amount numeric DEFAULT 0;

-- Step 2: Insert sample payment data
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
  ('STU001', 'Ama Mensah', 'ama.mensah@university.edu.gh', 'Computer Science', 'Level 200', 1500.00, 'Tuition', 'Partial', 50, 'TXN-20250101-001', 'RCPT-001', '2025-01-01 10:15:00+00', 'successful', 'momo_payments', 'REF-CS-001', '0241234567', 3000),
  ('STU002', 'Kwame Boateng', 'kwame.boateng@university.edu.gh', 'Business Admin', 'Level 300', 3000.00, 'Tuition', 'Full', 100, 'TXN-20250103-002', 'RCPT-002', '2025-01-03 14:40:00+00', 'successful', 'card_payments', 'REF-BA-002', '0559876543', 3000),
  ('STU003', 'Efua Asare', 'efua.asare@university.edu.gh', 'Nursing', 'Level 100', 500.00, 'Registration', 'Partial', 25, 'TXN-20250105-003', 'RCPT-003', '2025-01-05 09:05:00+00', 'pending', 'momo_payments', 'REF-NU-003', '0204567890', 2000),
  ('STU004', 'Kofi Adu', 'kofi.adu@university.edu.gh', 'Engineering', 'Level 400', 4500.00, 'Graduation', 'Full', 100, 'TXN-20250106-004', 'RCPT-004', '2025-01-06 16:30:00+00', 'failed', 'bank_transfer', 'REF-EN-004', '0263344556', 4000),
  ('STU005', 'Yaa Owusu', 'yaa.owusu@university.edu.gh', 'Economics', 'Level 200', 1200.00, 'Library', 'Partial', 40, 'TXN-20250107-005', 'RCPT-005', '2025-01-07 11:50:00+00', 'successful', 'momo_payments', 'REF-EC-005', '0507788991', 3000);

-- Step 3: Drop old eligibility view
DROP VIEW IF EXISTS student_payment_eligibility CASCADE;

-- Step 4: Create updated eligibility view that respects required amounts
-- Students need to pay 80% of required amount to be eligible
CREATE OR REPLACE VIEW student_payment_eligibility AS
SELECT 
  s.student_id,
  s.first_name || ' ' || COALESCE(s.middle_name || ' ', '') || s.surname AS full_name,
  s.email,
  s.phone_number,
  s.department,
  s.level,
  -- Required amount for this level (based on level)
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
  -- Amount still owing
  CASE 
    WHEN s.level = 'Level 100' THEN 2000
    WHEN s.level = 'Level 200' THEN 2500
    WHEN s.level = 'Level 300' THEN 3000
    WHEN s.level = 'Level 400' THEN 3500
    ELSE 2500
  END - COALESCE(SUM(CASE WHEN p.status IN ('approved', 'completed', 'success', 'successful') THEN p.amount ELSE 0 END), 0) as amount_owing,
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

-- Step 5: Create view for detailed payment tracking by student
DROP VIEW IF EXISTS student_payment_details CASCADE;

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
  -- All payments (success + pending + failed)
  COUNT(p.id) as total_payment_records,
  -- Successful payments only
  COUNT(CASE WHEN p.status IN ('approved', 'completed', 'success', 'successful') THEN 1 END) as successful_payments,
  -- Failed payments
  COUNT(CASE WHEN p.status = 'failed' THEN 1 END) as failed_payments,
  -- Pending payments
  COUNT(CASE WHEN p.status = 'pending' THEN 1 END) as pending_payments,
  -- Total successful amount
  COALESCE(SUM(CASE WHEN p.status IN ('approved', 'completed', 'success', 'successful') THEN p.amount ELSE 0 END), 0) as total_paid,
  -- Total failed amount
  COALESCE(SUM(CASE WHEN p.status = 'failed' THEN p.amount ELSE 0 END), 0) as total_failed,
  -- Total pending amount
  COALESCE(SUM(CASE WHEN p.status = 'pending' THEN p.amount ELSE 0 END), 0) as total_pending,
  -- 80% of required amount (eligibility threshold)
  ROUND((CASE 
    WHEN s.level = 'Level 100' THEN 2000
    WHEN s.level = 'Level 200' THEN 2500
    WHEN s.level = 'Level 300' THEN 3000
    WHEN s.level = 'Level 400' THEN 3500
    ELSE 2500
  END) * 0.80, 2) as amount_needed_for_eligibility,
  -- Amount still owing for eligibility
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
-- VERIFICATION QUERIES
-- ============================================================================

-- View 1: Student Payment Eligibility Status
-- Shows which students are eligible to register
SELECT * FROM student_payment_eligibility ORDER BY is_eligible_to_register DESC, last_payment_date DESC;

-- View 2: Student Payment Details
-- Shows detailed breakdown of payments per student
SELECT * FROM student_payment_details ORDER BY department, level;

-- View 3: Payments with Student Info
-- Shows all individual payment records
SELECT 
  p.student_id,
  p.student_name,
  p.department,
  p.level,
  p.amount,
  p.fee_type,
  p.status,
  p.payment_date
FROM payments_with_student_info p
ORDER BY p.payment_date DESC;

-- ============================================================================
-- REQUIRED FEES BY LEVEL (Reference)
-- ============================================================================
-- Level 100: GHS 2000
-- Level 200: GHS 2500
-- Level 300: GHS 3000
-- Level 400: GHS 3500
-- Eligibility: 80% of required amount must be paid

-- ============================================================================
-- SAMPLE QUERIES
-- ============================================================================

-- Get all eligible students
-- SELECT * FROM student_payment_eligibility WHERE is_eligible_to_register = true;

-- Get students not yet eligible with how much they still owe
-- SELECT 
--   full_name, 
--   department, 
--   level, 
--   total_paid, 
--   required_amount, 
--   amount_owing 
-- FROM student_payment_eligibility 
-- WHERE is_eligible_to_register = false 
-- ORDER BY amount_owing ASC;

-- Get payment summary by level
-- SELECT 
--   level,
--   COUNT(*) as student_count,
--   SUM(CAST(is_eligible_to_register AS INT)) as eligible_count,
--   ROUND(AVG(percentage_paid), 2) as avg_percentage_paid,
--   SUM(total_paid) as total_collected
-- FROM student_payment_eligibility
-- GROUP BY level;

-- Get payment summary by department
-- SELECT 
--   department,
--   COUNT(*) as student_count,
--   SUM(CAST(is_eligible_to_register AS INT)) as eligible_count,
--   ROUND(AVG(percentage_paid), 2) as avg_percentage_paid,
--   SUM(total_paid) as total_collected
-- FROM student_payment_eligibility
-- GROUP BY department;
