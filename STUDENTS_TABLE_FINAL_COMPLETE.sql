-- ========================================================================
-- COMPLETE student_master_db TABLE SETUP FOR GH SCHOOLS
-- Full production-ready SQL with all fixes and constraints
-- ========================================================================

-- SECTION 1: Create the student_master_db table
-- ========================================================================
CREATE TABLE IF NOT EXISTS student_master_db (
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
CREATE INDEX IF NOT EXISTS idx_student_id ON student_master_db(student_id);
CREATE INDEX IF NOT EXISTS idx_department ON student_master_db(department);
CREATE INDEX IF NOT EXISTS idx_level ON student_master_db(level);
CREATE INDEX IF NOT EXISTS idx_course_type ON student_master_db(course_type);
CREATE INDEX IF NOT EXISTS idx_email ON student_master_db(email);
CREATE INDEX IF NOT EXISTS idx_phone_number ON student_master_db(phone_number);
CREATE INDEX IF NOT EXISTS idx_created_at ON student_master_db(created_at);

-- SECTION 3: Create views for reporting
-- ========================================================================

-- Drop existing views first
DROP VIEW IF EXISTS active_students;
DROP VIEW IF EXISTS students_by_department;
DROP VIEW IF EXISTS students_by_level_and_type;

-- View 1: All students with full name
CREATE VIEW active_students AS
SELECT student_master_db.id, student_master_db.student_id, student_master_db.first_name, student_master_db.middle_name, student_master_db.surname, student_master_db.level, student_master_db.department, student_master_db.course_type, student_master_db.email, student_master_db.phone_number, student_master_db.whatsapp_number, student_master_db.created_at, student_master_db.updated_at
FROM student_master_db;

-- View 2: Summary by department
CREATE VIEW students_by_department AS
SELECT department, course_type, level, COUNT(*) as total_students
FROM student_master_db
GROUP BY department, course_type, level;

-- View 3: Summary by level and type
CREATE VIEW students_by_level_and_type AS
SELECT level, course_type, COUNT(*) as total_students
FROM student_master_db
GROUP BY level, course_type;
