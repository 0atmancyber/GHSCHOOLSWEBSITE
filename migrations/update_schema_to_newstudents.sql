-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "citext";

-- ------------------------------------------------------------
-- 1. Fee Types (unchanged)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fee_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    is_mandatory BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO fee_types (name, description, is_mandatory)
SELECT v.name, v.description, v.is_mandatory
FROM (VALUES
    ('Tuition', 'Semester tuition fee', true),
    ('SRC Dues', 'Students Representative Council dues', true),
    ('Medical Dues', 'Health service fee', true),
    ('Departmental Dues', 'Departmental levy', true)
) AS v(name, description, is_mandatory)
ON CONFLICT (name) DO NOTHING;

-- ------------------------------------------------------------
-- 2. Fee Schedules (unchanged)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fee_schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    fee_type_id UUID NOT NULL REFERENCES fee_types(id) ON DELETE CASCADE,
    fee_type TEXT,
    academic_year TEXT NOT NULL,
    semester TEXT,
    level TEXT,
    program TEXT,
    amount DECIMAL(10,2) NOT NULL CHECK (amount >= 0),
    total_amount DECIMAL(12,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (fee_type_id, academic_year, semester, level, program)
);

CREATE INDEX IF NOT EXISTS idx_fee_schedules_lookup ON fee_schedules (academic_year, semester, level, program);

-- ------------------------------------------------------------
-- 3. Payments – using citext for student_id and FK -> newstudents
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS payments (
    id BIGSERIAL PRIMARY KEY,
    student_id CITEXT NOT NULL,
    student_name TEXT,
    student_email TEXT,
    department TEXT,
    level TEXT,
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    phone TEXT,
    fee_type TEXT,
    fee_breakdown TEXT,
    payment_coverage TEXT,
    coverage_percent INTEGER,
    transaction_ref TEXT UNIQUE,
    receipt_number TEXT UNIQUE,
    payment_date TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'failed', 'refunded')),
    source_table TEXT,
    source_payload JSONB,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT fk_payments_student FOREIGN KEY (student_id)
        REFERENCES newstudents(student_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_payments_student_id ON payments (student_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments (status);
CREATE INDEX IF NOT EXISTS idx_payments_payment_date ON payments (payment_date);
CREATE INDEX IF NOT EXISTS idx_payments_level ON payments (level);
CREATE INDEX IF NOT EXISTS idx_payments_transaction_ref ON payments (transaction_ref);
CREATE INDEX IF NOT EXISTS idx_payments_receipt_number ON payments (receipt_number);

-- Optional: payment_items
CREATE TABLE IF NOT EXISTS payment_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payment_id BIGINT NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
    fee_type_id UUID REFERENCES fee_types(id),
    amount DECIMAL(10,2) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_items_payment_id ON payment_items (payment_id);

-- ------------------------------------------------------------
-- 4. Registrations – student_id as citext, FK -> newstudents
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS registrations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id CITEXT NOT NULL,
    level TEXT,
    school TEXT,
    program TEXT,
    courses JSONB,
    core_courses JSONB,
    contact_phone TEXT,
    contact_whatsapp TEXT,
    contact_email TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    notes TEXT,
    source_payload JSONB,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT fk_registrations_student FOREIGN KEY (student_id)
        REFERENCES newstudents(student_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_registrations_student_id ON registrations (student_id);
CREATE INDEX IF NOT EXISTS idx_registrations_created_at ON registrations (created_at);

-- ------------------------------------------------------------
-- 5. Notifications & notification_reads (student_id as citext) -> newstudents
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notification_reads (
    student_id CITEXT NOT NULL,
    notification_id UUID NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
    read_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (student_id, notification_id),
    CONSTRAINT fk_notif_reads_student FOREIGN KEY (student_id)
        REFERENCES newstudents(student_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_notification_reads_student_id ON notification_reads (student_id);

-- ------------------------------------------------------------
-- 6. SMS Messages – student_id as citext -> newstudents
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sms_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id CITEXT,
    phone TEXT NOT NULL,
    recipient_count INTEGER,
    message TEXT NOT NULL,
    status TEXT CHECK (status IN ('sent', 'failed')),
    gateway_response TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT fk_sms_student FOREIGN KEY (student_id)
        REFERENCES newstudents(student_id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_sms_messages_student_id ON sms_messages (student_id);
CREATE INDEX IF NOT EXISTS idx_sms_messages_created_at ON sms_messages (created_at);

-- ------------------------------------------------------------
-- 7. Audit Log (optional)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name TEXT NOT NULL,
    record_id TEXT NOT NULL,
    action TEXT CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_data JSONB,
    new_data JSONB,
    changed_by TEXT,
    changed_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_table_record ON audit_logs (table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_changed_at ON audit_logs (changed_at);

-- ------------------------------------------------------------
-- 8. Views for outstanding balance analysis (updated to newstudents)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW student_balances AS
WITH required_fees AS (
    SELECT
        s.student_id,
        s.level,
        ft.id AS fee_type_id,
        ft.name AS fee_name,
        COALESCE(fs.amount, 0) AS required_amount
    FROM newstudents s
    CROSS JOIN fee_types ft
    LEFT JOIN fee_schedules fs ON fs.fee_type_id = ft.id
        AND fs.level = s.level
        AND fs.academic_year = (SELECT MAX(academic_year) FROM fee_schedules)
        AND fs.semester = '1'
),
paid_fees AS (
    SELECT
        p.student_id,
        ft.id AS fee_type_id,
        SUM(p.amount) AS paid_amount
    FROM payments p
    LEFT JOIN fee_types ft ON LOWER(p.fee_breakdown) LIKE '%' || LOWER(ft.name) || '%'
    WHERE p.status = 'approved'
    GROUP BY p.student_id, ft.id
)
SELECT
    rf.student_id,
    s.first_name,
    s.surname,
    s.level,
    rf.fee_name,
    rf.required_amount,
    COALESCE(pf.paid_amount, 0) AS paid_amount,
    rf.required_amount - COALESCE(pf.paid_amount, 0) AS outstanding
FROM required_fees rf
JOIN newstudents s ON s.student_id = rf.student_id
LEFT JOIN paid_fees pf ON pf.student_id = rf.student_id AND pf.fee_type_id = rf.fee_type_id
ORDER BY rf.student_id, rf.fee_name;

CREATE OR REPLACE VIEW level_outstanding_summary AS
SELECT
    level,
    COUNT(DISTINCT student_id) AS total_students,
    SUM(required_amount) AS total_required,
    SUM(paid_amount) AS total_paid,
    SUM(outstanding) AS total_outstanding
FROM student_balances
GROUP BY level
ORDER BY level;

-- ------------------------------------------------------------
-- 9. Triggers for updated_at (unchanged)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_fee_schedules_updated_at ON fee_schedules;
CREATE TRIGGER trigger_fee_schedules_updated_at
    BEFORE UPDATE ON fee_schedules
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE FUNCTION fee_schedules_maintain_total()
RETURNS TRIGGER AS $$
DECLARE
    the_total NUMERIC := 0;
BEGIN
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        SELECT COALESCE(SUM(amount),0) INTO the_total
        FROM fee_schedules
        WHERE academic_year IS NOT DISTINCT FROM NEW.academic_year
          AND semester IS NOT DISTINCT FROM NEW.semester
          AND level IS NOT DISTINCT FROM NEW.level
          AND program IS NOT DISTINCT FROM NEW.program
          AND id IS DISTINCT FROM NEW.id;
        the_total := the_total + COALESCE(NEW.amount,0);
        NEW.total_amount := the_total;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_fee_schedules_maintain_total_before ON fee_schedules;
CREATE TRIGGER trigger_fee_schedules_maintain_total_before
    BEFORE INSERT OR UPDATE ON fee_schedules
    FOR EACH ROW EXECUTE FUNCTION fee_schedules_maintain_total();

CREATE OR REPLACE FUNCTION fee_schedules_propagate_total()
RETURNS TRIGGER AS $$
DECLARE
    scope_total NUMERIC := 0;
BEGIN
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        SELECT COALESCE(SUM(amount),0) INTO scope_total
        FROM fee_schedules
        WHERE academic_year IS NOT DISTINCT FROM NEW.academic_year
          AND semester IS NOT DISTINCT FROM NEW.semester
          AND level IS NOT DISTINCT FROM NEW.level
          AND program IS NOT DISTINCT FROM NEW.program;

        UPDATE fee_schedules
        SET total_amount = scope_total
        WHERE academic_year IS NOT DISTINCT FROM NEW.academic_year
          AND semester IS NOT DISTINCT FROM NEW.semester
          AND level IS NOT DISTINCT FROM NEW.level
          AND program IS NOT DISTINCT FROM NEW.program
          AND (total_amount IS DISTINCT FROM scope_total);
    ELSIF (TG_OP = 'DELETE') THEN
        SELECT COALESCE(SUM(amount),0) INTO scope_total
        FROM fee_schedules
        WHERE academic_year IS NOT DISTINCT FROM OLD.academic_year
          AND semester IS NOT DISTINCT FROM OLD.semester
          AND level IS NOT DISTINCT FROM OLD.level
          AND program IS NOT DISTINCT FROM OLD.program;

        UPDATE fee_schedules
        SET total_amount = scope_total
        WHERE academic_year IS NOT DISTINCT FROM OLD.academic_year
          AND semester IS NOT DISTINCT FROM OLD.semester
          AND level IS NOT DISTINCT FROM OLD.level
          AND program IS NOT DISTINCT FROM OLD.program
          AND (total_amount IS DISTINCT FROM scope_total);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_fee_schedules_propagate_total_after ON fee_schedules;
CREATE TRIGGER trigger_fee_schedules_propagate_total_after
    AFTER INSERT OR UPDATE OR DELETE ON fee_schedules
    FOR EACH ROW EXECUTE FUNCTION fee_schedules_propagate_total();

-- ------------------------------------------------------------
-- 10. Fee structure totals table and trigger
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fee_structure_totals (
    academic_year TEXT,
    semester TEXT,
    level TEXT,
    program TEXT,
    total_amount DECIMAL(18,2) NOT NULL DEFAULT 0,
    fee_count INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (academic_year, semester, level, program)
);

CREATE OR REPLACE FUNCTION fee_schedules_update_fee_structure_totals()
RETURNS TRIGGER AS $$
DECLARE
    ay TEXT; sem TEXT; lvl TEXT; prog TEXT;
    scope_total NUMERIC := 0; scope_count INTEGER := 0;
BEGIN
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        ay := COALESCE(NEW.academic_year, 'All');
        sem := COALESCE(NEW.semester, 'All');
        lvl := COALESCE(NEW.level, 'All');
        prog := COALESCE(NEW.program, 'All');
    ELSIF (TG_OP = 'DELETE') THEN
        ay := COALESCE(OLD.academic_year, 'All');
        sem := COALESCE(OLD.semester, 'All');
        lvl := COALESCE(OLD.level, 'All');
        prog := COALESCE(OLD.program, 'All');
    END IF;

    SELECT COALESCE(SUM(amount),0), COUNT(*) INTO scope_total, scope_count
    FROM fee_schedules
    WHERE COALESCE(academic_year, 'All') = ay
      AND COALESCE(semester, 'All') = sem
      AND COALESCE(level, 'All') = lvl
      AND COALESCE(program, 'All') = prog;

    IF scope_count = 0 THEN
        DELETE FROM fee_structure_totals
        WHERE academic_year = ay
            AND semester = sem
            AND level = lvl
            AND program = prog;
    ELSE
        INSERT INTO fee_structure_totals (academic_year, semester, level, program, total_amount, fee_count, updated_at)
        VALUES (ay, sem, lvl, prog, scope_total, scope_count, now())
        ON CONFLICT (academic_year, semester, level, program)
        DO UPDATE SET total_amount = EXCLUDED.total_amount, fee_count = EXCLUDED.fee_count, updated_at = EXCLUDED.updated_at;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_fee_schedules_update_fee_structure_totals ON fee_schedules;
CREATE TRIGGER trigger_fee_schedules_update_fee_structure_totals
    AFTER INSERT OR UPDATE OR DELETE ON fee_schedules
    FOR EACH ROW EXECUTE FUNCTION fee_schedules_update_fee_structure_totals();

DROP TRIGGER IF EXISTS trigger_payments_updated_at ON payments;
CREATE TRIGGER trigger_payments_updated_at
    BEFORE UPDATE ON payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_registrations_updated_at ON registrations;
CREATE TRIGGER trigger_registrations_updated_at
    BEFORE UPDATE ON registrations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
