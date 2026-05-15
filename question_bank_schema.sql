-- ═══════════════════════════════════════════════════════════════════
--  GH Schools Portal — Question Bank SQL Schema
--  Compatible with: PostgreSQL / Supabase
--  Generated for: GH Schools Ltd Portal
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- EXTENSIONS
-- ─────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";


-- ─────────────────────────────────────────────────────────────
-- ENUM TYPES
-- ─────────────────────────────────────────────────────────────

CREATE TYPE assessment_type AS ENUM (
  'ca',         -- Class Assessment
  'midsem',     -- Mid-Semester Exam
  'endsem'      -- End-of-Semester Exam
);

CREATE TYPE question_type AS ENUM (
  'theory',       -- Theory / Essay
  'mcq',          -- Multiple Choice Question
  'structured',   -- Structured
  'truefalse',    -- True / False
  'shortanswer'   -- Short Answer
);

CREATE TYPE difficulty_level AS ENUM (
  'easy',
  'medium',
  'hard'
);

CREATE TYPE upload_status AS ENUM (
  'pending',    -- File uploaded, not yet reviewed
  'approved',   -- Reviewed and accepted by admin
  'rejected',   -- Rejected by admin (with reason)
  'archived'    -- Archived / superseded
);

CREATE TYPE file_type AS ENUM (
  'docx',
  'pdf',
  'xlsx'
);

CREATE TYPE portal_role AS ENUM (
  'lecturer',
  'super_admin'
);


-- ─────────────────────────────────────────────────────────────
-- EXISTING TABLES (referenced by question bank — shown for clarity)
-- ─────────────────────────────────────────────────────────────

-- portal_users (existing — abbreviated)
-- CREATE TABLE portal_users (
--   id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--   email         TEXT UNIQUE NOT NULL,
--   full_name     TEXT NOT NULL,
--   portal_role   portal_role NOT NULL DEFAULT 'lecturer',
--   staff_id      TEXT,
--   department    TEXT,
--   phone         TEXT,
--   is_active     BOOLEAN DEFAULT TRUE,
--   last_login    TIMESTAMPTZ,
--   created_at    TIMESTAMPTZ DEFAULT NOW()
-- );

-- schools (existing — abbreviated)
-- CREATE TABLE schools (
--   id    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--   code  TEXT UNIQUE NOT NULL,  -- MEDIA, FASHION, CATERING, COSMETOLOGY, TECHNOLOGY
--   name  TEXT NOT NULL
-- );

-- courses (existing — abbreviated)
-- CREATE TABLE courses (
--   id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--   code       TEXT NOT NULL,
--   title      TEXT NOT NULL,
--   school_id  UUID REFERENCES schools(id),
--   level      INTEGER,
--   credit_hrs INTEGER
-- );

-- course_allocations (existing — abbreviated)
-- CREATE TABLE course_allocations (
--   id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--   lecturer_id  UUID REFERENCES portal_users(id),
--   course_id    UUID REFERENCES courses(id),
--   school       TEXT,
--   level        INTEGER,
--   program      TEXT,
--   semester     INTEGER,
--   academic_year TEXT,
--   is_active    BOOLEAN DEFAULT TRUE
-- );


-- ─────────────────────────────────────────────────────────────
-- TABLE: question_bank
--   Core table for individual questions entered manually
--   (lecturer typing directly in the portal)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE question_bank (
  id               UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- Ownership
  lecturer_id      UUID          NOT NULL REFERENCES portal_users(id) ON DELETE CASCADE,
  course_id        UUID          REFERENCES courses(id) ON DELETE SET NULL,
  course_code      TEXT,                           -- Denormalised for quick display
  course_title     TEXT,                           -- Denormalised for quick display

  -- Classification
  assessment_type  assessment_type NOT NULL,        -- ca | midsem | endsem
  question_type    question_type   NOT NULL,        -- theory | mcq | structured | truefalse | shortanswer
  difficulty       difficulty_level NOT NULL DEFAULT 'medium',

  -- Content
  question_text    TEXT          NOT NULL,
  model_answer     TEXT,                           -- Expected answer / marking scheme
  notes            TEXT,                           -- Instructions / examiner notes
  marks            SMALLINT      NOT NULL DEFAULT 5 CHECK (marks BETWEEN 1 AND 100),

  -- MCQ-specific
  options          JSONB,                          -- [{label:"A",text:"..."}, ...]
  correct_option   TEXT,                           -- "A" | "B" | "C" | "D"

  -- True/False-specific
  correct_tf       BOOLEAN,                        -- TRUE = answer is True

  -- Academic context
  semester         SMALLINT,
  academic_year    TEXT,
  school           TEXT,                           -- School code (MEDIA, FASHION, etc.)
  program          TEXT,

  -- Source tracking (NULL = typed manually; set when imported from a doc upload)
  source_upload_id UUID          REFERENCES question_bank_uploads(id) ON DELETE SET NULL,

  -- Soft delete & timestamps
  is_deleted       BOOLEAN       NOT NULL DEFAULT FALSE,
  created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Indexes for common query patterns
CREATE INDEX idx_qb_lecturer  ON question_bank (lecturer_id)   WHERE NOT is_deleted;
CREATE INDEX idx_qb_course    ON question_bank (course_id)     WHERE NOT is_deleted;
CREATE INDEX idx_qb_type      ON question_bank (assessment_type) WHERE NOT is_deleted;
CREATE INDEX idx_qb_school    ON question_bank (school)        WHERE NOT is_deleted;
CREATE INDEX idx_qb_created   ON question_bank (created_at DESC);

COMMENT ON TABLE  question_bank IS 'Individual exam / assessment questions submitted by lecturers.';
COMMENT ON COLUMN question_bank.options      IS 'JSON array of MCQ choices: [{label, text}]';
COMMENT ON COLUMN question_bank.correct_option IS 'Label of correct MCQ answer (A-D)';
COMMENT ON COLUMN question_bank.source_upload_id IS 'FK to question_bank_uploads when question was parsed from a document upload';


-- ─────────────────────────────────────────────────────────────
-- TABLE: question_bank_uploads
--   Stores metadata for doc/pdf files uploaded by lecturers.
--   Actual binary is stored in Supabase Storage bucket.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE question_bank_uploads (
  id               UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- Ownership
  lecturer_id      UUID          NOT NULL REFERENCES portal_users(id) ON DELETE CASCADE,
  course_id        UUID          REFERENCES courses(id) ON DELETE SET NULL,
  course_code      TEXT,
  course_title     TEXT,

  -- Classification
  assessment_type  assessment_type NOT NULL,

  -- File metadata
  original_filename TEXT         NOT NULL,
  storage_path     TEXT          NOT NULL UNIQUE,  -- Supabase Storage object path
  file_type        file_type     NOT NULL,         -- docx | pdf | xlsx
  file_size_bytes  INTEGER,

  -- Review workflow
  status           upload_status NOT NULL DEFAULT 'pending',
  reviewed_by      UUID          REFERENCES portal_users(id) ON DELETE SET NULL,
  reviewed_at      TIMESTAMPTZ,
  review_notes     TEXT,                           -- Admin feedback / rejection reason

  -- Parsed questions (how many questions were extracted from this upload)
  questions_extracted SMALLINT   DEFAULT 0,

  -- Academic context
  semester         SMALLINT,
  academic_year    TEXT,
  school           TEXT,
  program          TEXT,

  -- Timestamps
  uploaded_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_qbu_lecturer  ON question_bank_uploads (lecturer_id);
CREATE INDEX idx_qbu_status    ON question_bank_uploads (status);
CREATE INDEX idx_qbu_course    ON question_bank_uploads (course_id);
CREATE INDEX idx_qbu_school    ON question_bank_uploads (school);
CREATE INDEX idx_qbu_uploaded  ON question_bank_uploads (uploaded_at DESC);

COMMENT ON TABLE  question_bank_uploads IS 'Tracks document/PDF files uploaded by lecturers to the question bank.';
COMMENT ON COLUMN question_bank_uploads.storage_path IS 'Object path inside the Supabase Storage bucket question-bank-files';
COMMENT ON COLUMN question_bank_uploads.status IS 'Admin review workflow: pending → approved | rejected';


-- ─────────────────────────────────────────────────────────────
-- TABLE: question_bank_tags
--   Optional tagging system for better question organisation
-- ─────────────────────────────────────────────────────────────
CREATE TABLE question_bank_tags (
  id        UUID  PRIMARY KEY DEFAULT uuid_generate_v4(),
  tag_name  TEXT  NOT NULL UNIQUE,
  color     TEXT  DEFAULT '#22C55E'   -- hex colour for display badge
);

CREATE TABLE question_bank_question_tags (
  question_id  UUID  NOT NULL REFERENCES question_bank(id) ON DELETE CASCADE,
  tag_id       UUID  NOT NULL REFERENCES question_bank_tags(id) ON DELETE CASCADE,
  PRIMARY KEY (question_id, tag_id)
);

COMMENT ON TABLE question_bank_tags IS 'Optional tags (e.g. "Chapter 3", "Metabolism") for grouping questions.';


-- ─────────────────────────────────────────────────────────────
-- TABLE: question_bank_collections
--   A named set of questions (e.g. "Final 2025 Paper A")
--   assembled by the lecturer or admin from question_bank rows
-- ─────────────────────────────────────────────────────────────
CREATE TABLE question_bank_collections (
  id               UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_by       UUID          NOT NULL REFERENCES portal_users(id) ON DELETE CASCADE,
  course_id        UUID          REFERENCES courses(id) ON DELETE SET NULL,

  title            TEXT          NOT NULL,
  description      TEXT,
  assessment_type  assessment_type NOT NULL,
  semester         SMALLINT,
  academic_year    TEXT,

  is_locked        BOOLEAN       NOT NULL DEFAULT FALSE,  -- Locked collections cannot be edited
  total_marks      SMALLINT      DEFAULT 0,               -- updated by trigger when items change

  created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE TABLE question_bank_collection_items (
  id             UUID      PRIMARY KEY DEFAULT uuid_generate_v4(),
  collection_id  UUID      NOT NULL REFERENCES question_bank_collections(id) ON DELETE CASCADE,
  question_id    UUID      NOT NULL REFERENCES question_bank(id) ON DELETE CASCADE,
  sort_order     SMALLINT  NOT NULL DEFAULT 0,
  UNIQUE (collection_id, question_id)
);

COMMENT ON TABLE question_bank_collections IS 'Named exam paper / question set assembled from question_bank rows.';


-- ─────────────────────────────────────────────────────────────
-- TABLE: question_bank_export_log
--   Audit trail every time a paper / file is downloaded
-- ─────────────────────────────────────────────────────────────
CREATE TABLE question_bank_export_log (
  id             UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  exported_by    UUID          NOT NULL REFERENCES portal_users(id) ON DELETE SET NULL,
  collection_id  UUID          REFERENCES question_bank_collections(id) ON DELETE SET NULL,
  upload_id      UUID          REFERENCES question_bank_uploads(id) ON DELETE SET NULL,

  export_type    TEXT          NOT NULL,            -- 'paper_docx' | 'upload_file' | 'csv'
  course_code    TEXT,
  assessment_type assessment_type,
  question_count SMALLINT,
  file_name      TEXT,

  exported_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_qbel_user   ON question_bank_export_log (exported_by);
CREATE INDEX idx_qbel_date   ON question_bank_export_log (exported_at DESC);

COMMENT ON TABLE question_bank_export_log IS 'Audit log of every question bank export or file download action.';


-- ─────────────────────────────────────────────────────────────
-- SUPABASE STORAGE BUCKET (run via Supabase dashboard or API)
-- ─────────────────────────────────────────────────────────────
-- bucket name : question-bank-files
-- public      : false  (files accessed via signed URLs)
-- allowed MIME: application/pdf,
--               application/vnd.openxmlformats-officedocument.wordprocessingml.document,
--               application/msword
-- max file size: 20 MB
--
-- Object path convention:
--   {lecturer_id}/{academic_year}/{course_code}/{uuid}.{ext}
--   e.g. a1b2c3.../2025-2026/CS101/f9e8d7...pdf


-- ─────────────────────────────────────────────────────────────
-- ROW-LEVEL SECURITY (Supabase RLS)
-- ─────────────────────────────────────────────────────────────

-- Enable RLS on all question bank tables
ALTER TABLE question_bank          ENABLE ROW LEVEL SECURITY;
ALTER TABLE question_bank_uploads  ENABLE ROW LEVEL SECURITY;
ALTER TABLE question_bank_collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE question_bank_collection_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE question_bank_export_log ENABLE ROW LEVEL SECURITY;

-- ── question_bank policies ──
-- Lecturers can only see / edit their own questions
CREATE POLICY "lecturer_own_questions" ON question_bank
  FOR ALL USING (
    auth.uid() = lecturer_id
    OR EXISTS (
      SELECT 1 FROM portal_users
      WHERE id = auth.uid() AND portal_role = 'super_admin'
    )
  );

-- ── question_bank_uploads policies ──
CREATE POLICY "lecturer_own_uploads" ON question_bank_uploads
  FOR ALL USING (
    auth.uid() = lecturer_id
    OR EXISTS (
      SELECT 1 FROM portal_users
      WHERE id = auth.uid() AND portal_role = 'super_admin'
    )
  );

-- ── Admin-only export log read ──
CREATE POLICY "admin_export_log" ON question_bank_export_log
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM portal_users
      WHERE id = auth.uid() AND portal_role = 'super_admin'
    )
  );

CREATE POLICY "own_export_log" ON question_bank_export_log
  FOR INSERT WITH CHECK (auth.uid() = exported_by);


-- ─────────────────────────────────────────────────────────────
-- TRIGGERS — updated_at auto-stamp
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_qb_updated
  BEFORE UPDATE ON question_bank
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_qbu_updated
  BEFORE UPDATE ON question_bank_uploads
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_qbc_updated
  BEFORE UPDATE ON question_bank_collections
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Recompute total_marks on question_bank_collections when items are added/removed
CREATE OR REPLACE FUNCTION refresh_collection_total_marks()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  UPDATE question_bank_collections
  SET total_marks = (
    SELECT COALESCE(SUM(q.marks), 0)
    FROM question_bank_collection_items i
    JOIN question_bank q ON q.id = i.question_id
    WHERE i.collection_id = COALESCE(NEW.collection_id, OLD.collection_id)
  )
  WHERE id = COALESCE(NEW.collection_id, OLD.collection_id);
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_collection_marks
  AFTER INSERT OR DELETE ON question_bank_collection_items
  FOR EACH ROW EXECUTE FUNCTION refresh_collection_total_marks();


-- ─────────────────────────────────────────────────────────────
-- USEFUL VIEWS
-- ─────────────────────────────────────────────────────────────

-- Admin view: all questions with lecturer details
CREATE OR REPLACE VIEW v_admin_question_bank AS
SELECT
  q.id,
  q.assessment_type,
  q.question_type,
  q.difficulty,
  q.question_text,
  q.marks,
  q.course_code,
  q.course_title,
  q.school,
  q.program,
  q.semester,
  q.academic_year,
  q.created_at,
  q.source_upload_id,
  u.full_name   AS lecturer_name,
  u.staff_id    AS lecturer_staff_id,
  u.department  AS lecturer_department,
  u.email       AS lecturer_email
FROM question_bank q
JOIN portal_users u ON u.id = q.lecturer_id
WHERE q.is_deleted = FALSE;

-- Admin view: all uploads with reviewer and lecturer info
CREATE OR REPLACE VIEW v_admin_uploads AS
SELECT
  up.id,
  up.original_filename,
  up.file_type,
  up.file_size_bytes,
  up.assessment_type,
  up.status,
  up.questions_extracted,
  up.review_notes,
  up.uploaded_at,
  up.reviewed_at,
  up.course_code,
  up.course_title,
  up.school,
  up.program,
  up.semester,
  up.academic_year,
  up.storage_path,
  lec.full_name  AS lecturer_name,
  lec.email      AS lecturer_email,
  lec.staff_id   AS lecturer_staff_id,
  rev.full_name  AS reviewed_by_name
FROM question_bank_uploads up
JOIN portal_users lec ON lec.id = up.lecturer_id
LEFT JOIN portal_users rev ON rev.id = up.reviewed_by;

-- Summary stats per lecturer (admin dashboard widget)
CREATE OR REPLACE VIEW v_lecturer_question_stats AS
SELECT
  u.id          AS lecturer_id,
  u.full_name,
  u.department,
  COUNT(q.id)                                        AS total_questions,
  COUNT(q.id) FILTER (WHERE q.assessment_type='ca')      AS ca_count,
  COUNT(q.id) FILTER (WHERE q.assessment_type='midsem')  AS midsem_count,
  COUNT(q.id) FILTER (WHERE q.assessment_type='endsem')  AS endsem_count,
  COUNT(DISTINCT q.course_code)                      AS courses_covered,
  MAX(q.created_at)                                  AS last_added
FROM portal_users u
LEFT JOIN question_bank q
       ON q.lecturer_id = u.id AND q.is_deleted = FALSE
WHERE u.portal_role = 'lecturer'
GROUP BY u.id, u.full_name, u.department;


-- ─────────────────────────────────────────────────────────────
-- SEED DATA — Question Bank Tags
-- ─────────────────────────────────────────────────────────────
INSERT INTO question_bank_tags (tag_name, color) VALUES
  ('Chapter 1',  '#22C55E'),
  ('Chapter 2',  '#16A34A'),
  ('Chapter 3',  '#15803D'),
  ('Midterm',    '#EF4444'),
  ('Final',      '#DC2626'),
  ('Recall',     '#3B82F6'),
  ('Application','#F59E0B'),
  ('Analysis',   '#8B5CF6'),
  ('Past Paper', '#64748B')
ON CONFLICT (tag_name) DO NOTHING;
