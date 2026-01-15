-- Supabase SQL: create students and registrations tables
-- Run this in Supabase SQL editor (Project -> SQL)

-- Ensure pgcrypto is available for gen_random_uuid()
create extension if not exists "pgcrypto";

-- Students table: store full student info
create table if not exists students (
  id uuid primary key default gen_random_uuid(),
  first_name text,
  last_name text,
  full_name text,
  email text,
  phone text,
  date_of_birth date,
  gender text,
  address text,
  level text,
  school text,
  program text,
  metadata jsonb,
  created_at timestamptz default now()
);

-- Index for lookup by email or phone
create unique index if not exists idx_students_email on students((lower(email))) where email is not null;
create index if not exists idx_students_phone on students(phone) where phone is not null;

-- Registrations table: links to students and stores course selections
create table if not exists registrations (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references students(id) on delete cascade,
  level text,
  school text,
  program text,
  term text,
  courses jsonb,
  core_courses jsonb,
  status text default 'pending',
  notes text,
  created_at timestamptz default now()
);

-- Index for quick student lookups
create index if not exists idx_registrations_student_id on registrations(student_id);
create index if not exists idx_registrations_created_at on registrations(created_at desc);

-- Example: insert a student and registration (for testing)
-- insert into students (first_name,last_name,full_name,email,phone,level,school,program)
-- values ('Jane','Doe','Jane Doe','jane@example.com','+233501234567','100','Media School','Journalism And Media Art');

-- Then use the returned id to insert into registrations:
-- insert into registrations (student_id,level,school,program,courses,core_courses)
-- values ('<student-id>','100','Media School','Journalism And Media Art', '[]'::jsonb, '[]'::jsonb);

-- Notes:
-- - `courses` and `core_courses` are stored as JSON arrays (jsonb) so you can store an array of strings or objects.
-- - Optionally add Row Level Security (RLS) policies to restrict who can insert/read. For simple public inserts from the browser, configure RLS carefully and consider using a server endpoint for writes.

-- Optional RLS example for registrations (only allow inserts from authenticated users):
-- alter table registrations enable row level security;
-- create policy "Allow authenticated insert" on registrations
--   for insert using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- For more secure setups, create a dedicated RPC or server endpoint that uses a service role key (kept secret) to perform writes.
