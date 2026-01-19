-- Complete Students Table SQL
-- This table stores all student information for the GH Schools system

-- STEP 1: Create the students table
CREATE TABLE IF NOT EXISTS students (
  id BIGSERIAL PRIMARY KEY,
  student_id VARCHAR(50) UNIQUE NOT NULL,
  first_name VARCHAR(100) NOT NULL,
  middle_name VARCHAR(100),
  surname VARCHAR(100) NOT NULL,
  level VARCHAR(50),
  department VARCHAR(100),
  course_type VARCHAR(50),
  email VARCHAR(255),
  phone_number VARCHAR(20) NOT NULL,
  whatsapp_number VARCHAR(20) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- STEP 2: Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_student_id ON students(student_id);
CREATE INDEX IF NOT EXISTS idx_department ON students(department);
CREATE INDEX IF NOT EXISTS idx_level ON students(level);
CREATE INDEX IF NOT EXISTS idx_course_type ON students(course_type);
CREATE INDEX IF NOT EXISTS idx_email ON students(email);
CREATE INDEX IF NOT EXISTS idx_phone_number ON students(phone_number);
CREATE INDEX IF NOT EXISTS idx_created_at ON students(created_at);
