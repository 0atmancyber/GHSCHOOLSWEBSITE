-- ========================================================================
-- COURSE REGISTRATION TABLE FOR GH SCHOOLS
-- Stores all student course registrations
-- ========================================================================

-- SECTION 1: Create the registrations table
-- ========================================================================
CREATE TABLE IF NOT EXISTS registrations (
  id BIGSERIAL PRIMARY KEY,
  
  -- Student Identification
  student_id VARCHAR(50) NOT NULL,
  student_firstname VARCHAR(100),
  student_othername VARCHAR(100),
  student_lastname VARCHAR(100),
  student_full_name VARCHAR(255),
  student_email VARCHAR(255),
  student_phone VARCHAR(20),
  student_whatsapp VARCHAR(20),
  student_admission_number VARCHAR(50),
  
  -- Academic Information
  student_department VARCHAR(100),
  student_level VARCHAR(50),
  level VARCHAR(50),
  school VARCHAR(100),
  program VARCHAR(100),
  
  -- Course Selections
  courses TEXT[] DEFAULT '{}',
  core_courses TEXT[] DEFAULT '{}',
  
  -- Contact Information at Registration Time
  contact_phone VARCHAR(20),
  contact_whatsapp VARCHAR(20),
  contact_email VARCHAR(255),
  
  -- Registration Status
  status VARCHAR(50) DEFAULT 'pending',
  notes TEXT,
  
  -- Source Metadata
  source_payload JSONB,
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- SECTION 2: Create indexes for performance
-- ========================================================================
CREATE INDEX IF NOT EXISTS idx_registrations_student_id ON registrations(student_id);
CREATE INDEX IF NOT EXISTS idx_registrations_student_email ON registrations(student_email);
CREATE INDEX IF NOT EXISTS idx_registrations_department ON registrations(student_department);
CREATE INDEX IF NOT EXISTS idx_registrations_level ON registrations(student_level);
CREATE INDEX IF NOT EXISTS idx_registrations_status ON registrations(status);
CREATE INDEX IF NOT EXISTS idx_registrations_school ON registrations(school);
CREATE INDEX IF NOT EXISTS idx_registrations_program ON registrations(program);
CREATE INDEX IF NOT EXISTS idx_registrations_created_at ON registrations(created_at);

-- SECTION 3: Add foreign key constraint to student_master_db table
-- ========================================================================
ALTER TABLE IF EXISTS registrations
DROP CONSTRAINT IF EXISTS fk_registrations_students CASCADE;

ALTER TABLE registrations
ADD CONSTRAINT fk_registrations_students 
FOREIGN KEY (student_id) 
REFERENCES student_master_db(student_id) 
ON DELETE CASCADE 
ON UPDATE CASCADE;

-- SECTION 4: Create useful views for reporting
-- ========================================================================

-- View 1: All registrations with student info
DROP VIEW IF EXISTS registrations_with_student_info;
CREATE VIEW registrations_with_student_info AS
SELECT 
  r.id,
  r.student_id,
  r.student_full_name,
  r.student_email,
  r.student_department,
  r.student_level,
  r.school,
  r.program,
  r.status,
  r.created_at,
  r.updated_at,
  ARRAY_LENGTH(r.courses, 1) as num_courses,
  ARRAY_LENGTH(r.core_courses, 1) as num_core_courses,
  s.first_name,
  s.middle_name,
  s.surname,
  s.department,
  s.level,
  s.course_type
FROM registrations r
LEFT JOIN student_master_db s ON r.student_id = s.student_id
ORDER BY r.created_at DESC; 

-- View 2: Registration summary by status
DROP VIEW IF EXISTS registrations_by_status;
CREATE VIEW registrations_by_status AS
SELECT 
  status,
  COUNT(*) as total_registrations,
  COUNT(DISTINCT student_id) as unique_students
FROM registrations
GROUP BY status
ORDER BY total_registrations DESC;

-- View 3: Registration summary by department
DROP VIEW IF EXISTS registrations_by_department;
CREATE VIEW registrations_by_department AS
SELECT 
  student_department,
  COUNT(*) as total_registrations,
  COUNT(DISTINCT student_id) as unique_students,
  COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_count,
  COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_count
FROM registrations
WHERE student_department IS NOT NULL
GROUP BY student_department
ORDER BY total_registrations DESC;

-- View 4: Students who have registered
DROP VIEW IF EXISTS students_registered;
CREATE VIEW students_registered AS
SELECT DISTINCT 
  r.student_id,
  r.student_full_name,
  r.student_department,
  r.student_level,
  r.school,
  r.status,
  r.created_at,
  s.course_type
FROM registrations r
LEFT JOIN student_master_db s ON r.student_id = s.student_id
ORDER BY r.created_at DESC;

-- SECTION 5: Database documentation
-- ========================================================================
COMMENT ON TABLE registrations IS 'Stores course registration records for students including selected courses, personal information snapshot at time of registration, and registration status';

COMMENT ON COLUMN registrations.id IS 'Auto-incrementing primary key';
COMMENT ON COLUMN registrations.student_id IS 'Student ID (references student_master_db table)';
COMMENT ON COLUMN registrations.student_firstname IS 'Student first name at time of registration';
COMMENT ON COLUMN registrations.student_othername IS 'Student other/middle name at time of registration';
COMMENT ON COLUMN registrations.student_lastname IS 'Student last name at time of registration';
COMMENT ON COLUMN registrations.student_full_name IS 'Student full name at time of registration';
COMMENT ON COLUMN registrations.student_email IS 'Student email at time of registration';
COMMENT ON COLUMN registrations.student_phone IS 'Student phone at time of registration';
COMMENT ON COLUMN registrations.student_whatsapp IS 'Student WhatsApp number at time of registration';
COMMENT ON COLUMN registrations.student_admission_number IS 'Student admission number at time of registration';
COMMENT ON COLUMN registrations.student_department IS 'Student department at time of registration';
COMMENT ON COLUMN registrations.student_level IS 'Student level at time of registration';
COMMENT ON COLUMN registrations.level IS 'Academic level (Level 100, 200, 300, 400)';
COMMENT ON COLUMN registrations.school IS 'School/department (Media School, Fashion, Catering, etc)';
COMMENT ON COLUMN registrations.program IS 'Program name within the school';
COMMENT ON COLUMN registrations.courses IS 'Array of selected program courses';
COMMENT ON COLUMN registrations.core_courses IS 'Array of selected core courses';
COMMENT ON COLUMN registrations.contact_phone IS 'Phone number provided at registration';
COMMENT ON COLUMN registrations.contact_whatsapp IS 'WhatsApp number provided at registration';
COMMENT ON COLUMN registrations.contact_email IS 'Email provided at registration';
COMMENT ON COLUMN registrations.status IS 'Registration status: pending, completed, approved, rejected';
COMMENT ON COLUMN registrations.notes IS 'Admin notes about the registration';
COMMENT ON COLUMN registrations.source_payload IS 'Complete source data JSON payload at time of registration';
COMMENT ON COLUMN registrations.created_at IS 'Timestamp when registration was created';
COMMENT ON COLUMN registrations.updated_at IS 'Timestamp when registration was last updated';

COMMENT ON VIEW registrations_with_student_info IS 'View showing registrations with current student information joined from student_master_db table';
COMMENT ON VIEW registrations_by_status IS 'View showing count of registrations grouped by status';
COMMENT ON VIEW registrations_by_department IS 'View showing registration statistics by department';
COMMENT ON VIEW students_registered IS 'View showing all unique students who have registered with their latest registration info';

-- ========================================================================
-- INSTALLATION COMPLETE
-- ========================================================================
-- The registrations table is now ready to use with:
-- ✓ Full schema for storing course registrations
-- ✓ Student information snapshot at registration time
-- ✓ Course selection arrays (courses + core courses)
-- ✓ Contact information at registration time
-- ✓ Status tracking (pending, completed, etc)
-- ✓ Foreign key linking to student_master_db table with CASCADE delete
-- ✓ Performance indexes on frequently queried columns
-- ✓ 4 useful views for reporting and analysis
-- ✓ Complete documentation
-- ========================================================================
