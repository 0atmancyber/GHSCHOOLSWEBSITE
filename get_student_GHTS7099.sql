-- Query to fetch student GHTS7099 details
SELECT 
  student_id,
  first_name,
  middle_name,
  surname,
  email,
  current_level,
  school,
  phone_number,
  whatsapp_number
FROM students
WHERE student_id = 'GHTS7099';
