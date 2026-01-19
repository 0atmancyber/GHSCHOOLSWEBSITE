-- Rename current_level column to level
ALTER TABLE students RENAME COLUMN current_level TO level;

-- Rename school column to department
ALTER TABLE students RENAME COLUMN school TO department;

-- Update the view for students by department
CREATE OR REPLACE VIEW students_by_department AS
SELECT 
  department,
  COUNT(*) as total_students,
  COUNT(CASE WHEN level = 'Level 100' THEN 1 END) as level_100,
  COUNT(CASE WHEN level = 'Level 200' THEN 1 END) as level_200,
  COUNT(CASE WHEN level = 'Level 300' THEN 1 END) as level_300,
  COUNT(CASE WHEN level = 'Level 400' THEN 1 END) as level_400
FROM students
GROUP BY department;

-- Update the view for students by level
CREATE OR REPLACE VIEW students_by_level AS
SELECT 
  level,
  COUNT(*) as total_students
FROM students
GROUP BY level
ORDER BY level;

-- Rename the indexes to match new column names
DROP INDEX IF EXISTS idx_students_current_level;
DROP INDEX IF EXISTS idx_students_school;

CREATE INDEX IF NOT EXISTS idx_students_level ON students(level);
CREATE INDEX IF NOT EXISTS idx_students_department ON students(department);
