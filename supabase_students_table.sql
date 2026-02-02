-- Create student_master_db table
CREATE TABLE IF NOT EXISTS student_master_db (
  id BIGSERIAL PRIMARY KEY,
  student_id VARCHAR(50) NOT NULL UNIQUE,
  first_name VARCHAR(100) NOT NULL,
  middle_name VARCHAR(100),
  surname VARCHAR(100) NOT NULL,
  current_level VARCHAR(50) NOT NULL,
  school VARCHAR(100) NOT NULL,
  phone_number VARCHAR(20) NOT NULL,
  whatsapp_number VARCHAR(20) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index on student_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_student_master_db_student_id ON student_master_db(student_id);

-- Create index on school for filtering by school
CREATE INDEX IF NOT EXISTS idx_student_master_db_school ON student_master_db(school);

-- Create index on current_level for filtering by level
CREATE INDEX IF NOT EXISTS idx_student_master_db_current_level ON student_master_db(current_level);

-- Create index on phone_number for contact purposes
CREATE INDEX IF NOT EXISTS idx_student_master_db_phone ON student_master_db(phone_number);

-- Create index on whatsapp_number for contact purposes
CREATE INDEX IF NOT EXISTS idx_student_master_db_whatsapp ON student_master_db(whatsapp_number);

-- Optional: Create a view to count students by school
CREATE OR REPLACE VIEW students_by_school AS
SELECT 
  school,
  COUNT(*) as total_students,
  COUNT(CASE WHEN current_level = 'Level 100' THEN 1 END) as level_100,
  COUNT(CASE WHEN current_level = 'Level 200' THEN 1 END) as level_200,
  COUNT(CASE WHEN current_level = 'Level 300' THEN 1 END) as level_300,
  COUNT(CASE WHEN current_level = 'Level 400' THEN 1 END) as level_400
FROM student_master_db
GROUP BY school;

-- Optional: Create a view to count students by level
CREATE OR REPLACE VIEW students_by_level AS
SELECT 
  current_level,
  COUNT(*) as total_students
FROM student_master_db
GROUP BY current_level
ORDER BY current_level;

-- Enable RLS (Row Level Security) - optional but recommended
ALTER TABLE student_master_db ENABLE ROW LEVEL SECURITY;

-- Create policy to allow anyone to insert (for registration)
CREATE POLICY "Allow insert for anonymous users" ON student_master_db
  FOR INSERT
  WITH CHECK (true);

-- Create policy to allow anyone to read their own data
CREATE POLICY "Allow read for all users" ON student_master_db
  FOR SELECT
  USING (true);

-- Create policy to allow users to update their own data
CREATE POLICY "Allow update for users" ON student_master_db
  FOR UPDATE
  USING (true)
  WITH CHECK (true);
