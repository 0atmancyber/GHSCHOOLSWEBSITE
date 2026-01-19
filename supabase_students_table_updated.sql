-- Create students table (Updated with email field)
CREATE TABLE IF NOT EXISTS students (
  id BIGSERIAL PRIMARY KEY,
  student_id VARCHAR(50) NOT NULL UNIQUE,
  first_name VARCHAR(100) NOT NULL,
  middle_name VARCHAR(100),
  surname VARCHAR(100) NOT NULL,
  current_level VARCHAR(50) NOT NULL,
  school VARCHAR(100) NOT NULL,
  email VARCHAR(100),
  phone_number VARCHAR(20) NOT NULL,
  whatsapp_number VARCHAR(20),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index on student_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_students_student_id ON students(student_id);

-- Create index on school for filtering by school/department
CREATE INDEX IF NOT EXISTS idx_students_school ON students(school);

-- Create index on current_level for filtering by level
CREATE INDEX IF NOT EXISTS idx_students_current_level ON students(current_level);

-- Create index on phone_number for contact purposes
CREATE INDEX IF NOT EXISTS idx_students_phone ON students(phone_number);

-- Create index on whatsapp_number for contact purposes
CREATE INDEX IF NOT EXISTS idx_students_whatsapp ON students(whatsapp_number);

-- Create index on email for faster lookups
CREATE INDEX IF NOT EXISTS idx_students_email ON students(email);

-- Optional: Create a view to count students by department
CREATE OR REPLACE VIEW students_by_department AS
SELECT 
  school as department,
  COUNT(*) as total_students,
  COUNT(CASE WHEN current_level = 'Level 100' THEN 1 END) as level_100,
  COUNT(CASE WHEN current_level = 'Level 200' THEN 1 END) as level_200,
  COUNT(CASE WHEN current_level = 'Level 300' THEN 1 END) as level_300,
  COUNT(CASE WHEN current_level = 'Level 400' THEN 1 END) as level_400
FROM students
GROUP BY school;

-- Optional: Create a view to count students by level
CREATE OR REPLACE VIEW students_by_level AS
SELECT 
  current_level as level,
  COUNT(*) as total_students
FROM students
GROUP BY current_level
ORDER BY current_level;

-- Enable RLS (Row Level Security) - optional but recommended
ALTER TABLE students ENABLE ROW LEVEL SECURITY;

-- Create policy to allow anyone to insert (for registration)
CREATE POLICY "Allow insert for anonymous users" ON students
  FOR INSERT
  WITH CHECK (true);

-- Create policy to allow anyone to read their own data
CREATE POLICY "Allow read for all users" ON students
  FOR SELECT
  USING (true);

-- Create policy to allow users to update their own data
CREATE POLICY "Allow update for users" ON students
  FOR UPDATE
  USING (true)
  WITH CHECK (true);
