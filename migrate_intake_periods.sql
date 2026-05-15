-- ============================================================
-- MIGRATION: Intake Period System
--
-- School structure (each level = one semester of one year):
--   Level 100 → January  (e.g. "January 2026")
--   Level 200 → June     (e.g. "June 2026")
--   Level 300 → January  (e.g. "January 2027")
--   Level 400 → June     (e.g. "June 2027")
--
-- fee_schedules columns after migration:
--   academic_year  TEXT  →  plain 4-digit year, e.g. '2026'
--   semester       TEXT  →  'January' | 'June'   (never '1' / '2')
-- ============================================================

-- ── Step 1: Drop dependent views FIRST ───────────────────────
-- Cannot use CREATE OR REPLACE VIEW when column names change.
-- CASCADE drops level_outstanding_summary automatically too.
DROP VIEW IF EXISTS level_outstanding_summary CASCADE;
DROP VIEW IF EXISTS student_balances CASCADE;

-- ── Step 2: Replace CHECK constraint ─────────────────────────
ALTER TABLE fee_schedules
    DROP CONSTRAINT IF EXISTS fee_schedules_semester_check;

ALTER TABLE fee_schedules
    ADD CONSTRAINT fee_schedules_semester_check
    CHECK (semester IN ('January', 'June') OR semester IS NULL);

-- ── Step 3: Migrate legacy semester values ────────────────────
UPDATE fee_schedules SET semester = 'January' WHERE semester = '1';
UPDATE fee_schedules SET semester = 'June'    WHERE semester = '2';

-- ── Step 4: Normalise academic_year → plain 4-digit year ──────
--   '2024-2025' → '2025'
--   '2025'      → unchanged
UPDATE fee_schedules
    SET academic_year = SPLIT_PART(academic_year, '-', 2)
    WHERE academic_year LIKE '____-____';

-- ── Step 5: Rebuild views ─────────────────────────────────────
DO $$
DECLARE
    level_col         TEXT;
    level_type        TEXT;
    level_select      TEXT;
    level_join_cond   TEXT;
    intake_join_cond  TEXT;
    first_name_col    TEXT;
    last_name_col     TEXT;
    first_name_select TEXT;
    last_name_select  TEXT;
    v_sql             TEXT;
BEGIN
    -- ── Detect level column ──────────────────────────────────
    SELECT column_name INTO level_col
    FROM information_schema.columns
    WHERE table_name = 'newstudents'
      AND column_name IN (
          'level','student_level','academic_level',
          'school_year','year','class','grade')
    ORDER BY CASE
        WHEN column_name = 'level'          THEN 1
        WHEN column_name = 'student_level'  THEN 2
        WHEN column_name = 'academic_level' THEN 3
        WHEN column_name = 'school_year'    THEN 4
        WHEN column_name = 'year'           THEN 5
        ELSE 10 END
    LIMIT 1;

    IF level_col IS NOT NULL THEN
        SELECT data_type INTO level_type
        FROM information_schema.columns
        WHERE table_name = 'newstudents'
          AND column_name = level_col LIMIT 1;

        level_type := COALESCE(level_type, 'text');

        IF level_type IN ('integer','bigint','smallint','numeric') THEN
            level_select     := format('s.%I::text AS level', level_col);
            level_join_cond  := format('AND fs.level = s.%I::text', level_col);
            intake_join_cond := format(
                $j$AND fs.semester = CASE
                    WHEN s.%I::text IN ('100','300') THEN 'January'
                    WHEN s.%I::text IN ('200','400') THEN 'June'
                    ELSE 'January' END$j$,
                level_col, level_col);
        ELSE
            level_select     := format('s.%I AS level', level_col);
            level_join_cond  := format('AND fs.level = s.%I', level_col);
            intake_join_cond := format(
                $j$AND fs.semester = CASE
                    WHEN s.%I IN ('100','300') THEN 'January'
                    WHEN s.%I IN ('200','400') THEN 'June'
                    ELSE 'January' END$j$,
                level_col, level_col);
        END IF;
    ELSE
        level_select     := quote_nullable('All') || '::text AS level';
        level_join_cond  := '';
        intake_join_cond := '';
    END IF;

    -- ── Detect first name column ─────────────────────────────
    SELECT column_name INTO first_name_col
    FROM information_schema.columns
    WHERE table_name = 'newstudents'
      AND column_name IN ('first_name','firstname','fname','given_name','forename')
    ORDER BY CASE
        WHEN column_name = 'first_name' THEN 1
        WHEN column_name = 'firstname'  THEN 2
        WHEN column_name = 'fname'      THEN 3
        ELSE 10 END
    LIMIT 1;

    first_name_select := CASE
        WHEN first_name_col IS NULL
            THEN quote_nullable('Unknown') || '::text AS first_name'
        ELSE format('s.%I AS first_name', first_name_col)
    END;

    -- ── Detect last name column ──────────────────────────────
    SELECT column_name INTO last_name_col
    FROM information_schema.columns
    WHERE table_name = 'newstudents'
      AND column_name IN ('surname','last_name','lastname','lname','family_name')
    ORDER BY CASE
        WHEN column_name = 'surname'   THEN 1
        WHEN column_name = 'last_name' THEN 2
        WHEN column_name = 'lastname'  THEN 3
        ELSE 10 END
    LIMIT 1;

    last_name_select := CASE
        WHEN last_name_col IS NULL
            THEN quote_nullable('') || '::text AS last_name'
        ELSE format('s.%I AS last_name', last_name_col)
    END;

    -- ── Create student_balances view ─────────────────────────
    -- Views were already DROPped above, so CREATE (not REPLACE) is safe.
    v_sql := format($sql$
        CREATE VIEW student_balances AS
        WITH required_fees AS (
            SELECT
                s.student_id,
                %s,
                ft.id   AS fee_type_id,
                ft.name AS fee_name,
                COALESCE(fs.semester,     'January') AS intake_month,
                COALESCE(fs.academic_year,
                    (SELECT MAX(academic_year) FROM fee_schedules)
                ) AS intake_year,
                COALESCE(fs.amount, 0) AS required_amount
            FROM newstudents s
            CROSS JOIN fee_types ft
            LEFT JOIN fee_schedules fs
                ON  fs.fee_type_id   = ft.id
                %s
                %s
                AND fs.academic_year = (SELECT MAX(academic_year) FROM fee_schedules)
        ),
        paid_fees AS (
            SELECT
                p.student_id,
                ft.id AS fee_type_id,
                SUM(p.amount) AS paid_amount
            FROM payments p
            LEFT JOIN fee_types ft
                ON LOWER(p.fee_breakdown) LIKE '%%' || LOWER(ft.name) || '%%'
            WHERE p.status = 'approved'
            GROUP BY p.student_id, ft.id
        )
        SELECT
            rf.student_id,
            %s,
            %s,
            %s,
            rf.fee_name,
            rf.intake_month,
            rf.intake_year,
            (rf.intake_month || ' ' || rf.intake_year) AS intake_period,
            rf.required_amount,
            COALESCE(pf.paid_amount, 0)                AS paid_amount,
            rf.required_amount
                - COALESCE(pf.paid_amount, 0)          AS outstanding
        FROM required_fees rf
        JOIN newstudents s ON s.student_id = rf.student_id
        LEFT JOIN paid_fees pf
            ON  pf.student_id  = rf.student_id
            AND pf.fee_type_id = rf.fee_type_id
        ORDER BY rf.student_id, rf.fee_name;
    $sql$,
        level_select,       -- CTE: level column
        level_join_cond,    -- JOIN: level match
        intake_join_cond,   -- JOIN: semester match
        first_name_select,  -- outer SELECT
        last_name_select,   -- outer SELECT
        level_select        -- outer SELECT (level again)
    );

    EXECUTE v_sql;

    -- ── Create level_outstanding_summary view ────────────────
    EXECUTE $v$
        CREATE VIEW level_outstanding_summary AS
        SELECT
            level,
            intake_month,
            intake_year,
            intake_period,
            COUNT(DISTINCT student_id) AS total_students,
            SUM(required_amount)       AS total_required,
            SUM(paid_amount)           AS total_paid,
            SUM(outstanding)           AS total_outstanding
        FROM student_balances
        GROUP BY level, intake_month, intake_year, intake_period
        ORDER BY intake_year DESC, level, intake_month;
    $v$;

END;
$$ LANGUAGE plpgsql;

-- ── Verify ────────────────────────────────────────────────────
-- Run these after migration to confirm everything looks right:
--
--   SELECT DISTINCT semester, academic_year
--   FROM fee_schedules
--   ORDER BY academic_year, semester;
--
--   SELECT * FROM level_outstanding_summary LIMIT 20;
