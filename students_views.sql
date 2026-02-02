-- VIEWS FOR student_master_db TABLE (Run this AFTER the main table creation)
-- These are optional views for reporting and analysis

-- View 1: Active students with full name
CREATE VIEW IF NOT EXISTS active_students AS
SELECT 
  id,
  student_id,
  first_name,
  middle_name,
  surname,
  (first_name || ' ' || COALESCE(middle_name || ' ', '') || surname) AS full_name,
  level,
  department,
  course_type,
  email,
  phone_number,
  whatsapp_number,
  created_at,
  updated_at
FROM student_master_db
ORDER BY created_at DESC;

-- View 2: Summary by department
CREATE VIEW IF NOT EXISTS students_by_department AS
SELECT 
  department,
  course_type,
  level,
  COUNT(*) AS total_students,
  COUNT(CASE WHEN course_type = 'Diploma' THEN 1 END) AS diploma_count,
  COUNT(CASE WHEN course_type = 'ICC' THEN 1 END) AS icc_count
FROM student_master_db
WHERE department IS NOT NULL
GROUP BY department, course_type, level
ORDER BY department, level;

-- View 3: Summary by level and course type
CREATE VIEW IF NOT EXISTS students_by_level_and_type AS
SELECT 
  level,
  course_type,
  department,
  COUNT(*) AS total_students
FROM student_master_db
WHERE level IS NOT NULL AND course_type IS NOT NULL
GROUP BY level, course_type, department
ORDER BY level, course_type;
