-- Best Practices for Payments & Students Integration

-- Option 1: Query payments with latest student data (RECOMMENDED)
-- Use this when you need current student information
SELECT 
  p.id,
  p.student_id,
  s.first_name,
  s.middle_name,
  s.surname,
  s.email,
  s.phone_number,
  s.whatsapp_number,
  s.department,
  s.level,
  p.amount,
  p.fee_type,
  p.payment_date,
  p.status
FROM payments p
LEFT JOIN students s ON p.student_id = s.student_id
WHERE p.status IN ('completed', 'approved', 'success')
ORDER BY p.payment_date DESC;

-- Option 2: Use the view (if created)
-- Much simpler and maintains consistency
SELECT * FROM payments_with_student_info 
WHERE status IN ('completed', 'approved', 'success');

-- Option 3: Get payment summary by student
SELECT 
  s.student_id,
  s.first_name || ' ' || COALESCE(s.middle_name || ' ', '') || s.surname AS full_name,
  s.department,
  s.level,
  COUNT(p.id) as payment_count,
  SUM(CASE WHEN p.status IN ('completed', 'approved', 'success') THEN p.amount ELSE 0 END) as total_paid,
  MAX(p.payment_date) as last_payment
FROM students s
LEFT JOIN payments p ON s.student_id = p.student_id
GROUP BY s.student_id, s.first_name, s.middle_name, s.surname, s.department, s.level;

-- Query to check for payments with mismatched student data
-- This helps identify records that need updating
SELECT 
  p.student_id,
  p.student_name,
  s.first_name || ' ' || COALESCE(s.middle_name || ' ', '') || s.surname AS current_full_name,
  p.student_email,
  s.email AS current_email,
  p.department,
  s.department AS current_department,
  p.level,
  s.level AS current_level
FROM payments p
LEFT JOIN students s ON p.student_id = s.student_id
WHERE 
  (p.student_name IS DISTINCT FROM (s.first_name || ' ' || COALESCE(s.middle_name || ' ', '') || s.surname))
  OR p.student_email IS DISTINCT FROM s.email
  OR p.department IS DISTINCT FROM s.department
  OR p.level IS DISTINCT FROM s.level;
