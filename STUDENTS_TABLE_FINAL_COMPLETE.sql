-- ========================================================================
-- COMPLETE STUDENTS TABLE SETUP FOR GH SCHOOLS
-- Full production-ready SQL with all fixes and constraints
-- ========================================================================

-- SECTION 1: Create the students table
-- ========================================================================
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

-- SECTION 2: Create indexes for performance
-- ========================================================================
CREATE INDEX IF NOT EXISTS idx_student_id ON students(student_id);
CREATE INDEX IF NOT EXISTS idx_department ON students(department);
CREATE INDEX IF NOT EXISTS idx_level ON students(level);
CREATE INDEX IF NOT EXISTS idx_course_type ON students(course_type);
CREATE INDEX IF NOT EXISTS idx_email ON students(email);
CREATE INDEX IF NOT EXISTS idx_phone_number ON students(phone_number);
CREATE INDEX IF NOT EXISTS idx_created_at ON students(created_at);

-- SECTION 3: Create views for reporting
-- ========================================================================

-- Drop existing views first
DROP VIEW IF EXISTS active_students;
DROP VIEW IF EXISTS students_by_department;
DROP VIEW IF EXISTS students_by_level_and_type;

-- View 1: All students with full name
CREATE VIEW active_students AS
SELECT students.id, students.student_id, students.first_name, students.middle_name, students.surname, students.level, students.department, students.course_type, students.email, students.phone_number, students.whatsapp_number, students.created_at, students.updated_at
FROM students;

-- View 2: Summary by department
CREATE VIEW students_by_department AS
SELECT department, course_type, level, COUNT(*) as total_students
FROM students
GROUP BY department, course_type, level;

-- View 3: Summary by level and type
CREATE VIEW students_by_level_and_type AS
SELECT level, course_type, COUNT(*) as total_students
FROM students
GROUP BY level, course_type;
