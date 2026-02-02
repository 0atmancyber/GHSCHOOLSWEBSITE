-- Test query to verify student data after updates
SELECT 
  student_id,
  first_name,
  middle_name,
  surname,
  email,
  current_level,
  school,
  phone_number,
  whatsapp_number,
  created_at,
  updated_at
FROM student_master_db
WHERE student_id = 'GHTS7099'
ORDER BY updated_at DESC
LIMIT 1; 

-- If you want to verify multiple students with names populated:
SELECT 
  student_id,
  first_name || ' ' || COALESCE(middle_name || ' ', '') || surname AS full_name,
  email,
  school,
  current_level
FROM student_master_db
WHERE first_name != 'Unknown' 
  AND first_name IS NOT NULL
  AND first_name != ''
ORDER BY updated_at DESC
LIMIT 10;
