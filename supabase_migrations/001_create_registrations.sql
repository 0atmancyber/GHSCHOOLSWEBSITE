-- Migration: create registrations table (use with Supabase SQL editor)
create extension if not exists "pgcrypto";

create table if not exists registrations (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references student_master_db(id) on delete cascade,
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

create index if not exists idx_registrations_student_id on registrations(student_id);
create index if not exists idx_registrations_created_at on registrations(created_at desc);
