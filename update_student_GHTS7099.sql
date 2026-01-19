-- Update student GHTS7099 with correct names
UPDATE students
SET 
  first_name = 'ALEX',
  middle_name = 'TWUM',
  surname = 'OSEI',
  updated_at = CURRENT_TIMESTAMP
WHERE student_id = 'GHTS7099';

-- Verify the update
SELECT 
  student_id,
  first_name,
  middle_name,
  surname,
  email,
  current_level,
  school
FROM students
WHERE student_id = 'GHTS7099';
