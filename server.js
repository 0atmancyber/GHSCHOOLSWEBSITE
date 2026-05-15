require('dotenv').config();
const express = require('express');
const { Pool } = require('pg');
const path = require('path');

const app = express();
const port = process.env.PORT || 3000;

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

app.use(express.json());
app.use(express.static(path.join(__dirname)));

const allowedCols = new Set([
  'student_id', 'first_name', 'middle_name', 'last_name', 'dob', 'gender', 'phone_number', 'email', 'home_address',
  'nationality', 'national_id_type', 'national_id_number', 'present_job', 'language_spoken', 'region', 'current_residence',
  'hostel_preference', 'any_medical', 'medical_spec', 'disability_spec', 'heard_source', 'heard_spec',
  'sponsor_name', 'sponsor_relationship', 'sponsor_occupation', 'sponsor_address', 'sponsor_phone',
  'school_name', 'school_location', 'school_year', 'school_qualification',
  'preferred_major', 'program_duration', 'course_type', 'program_applying_for',
  'passport_photo_url', 'wassce_results_url', 'english_grade', 'mathematics_grade', 'social_studies_grade', 'integrated_science_grade',
  'wassce_core_score', 'wassce_core_average', 'reference_code', 'status', 'full_name', 'preferred_major', 'emergency_contact',
  'signature_1', 'declaration_date_1', 'signature_2', 'declaration_date_2', 'is_admission_form'
]);

app.post('/api/newstudents', async (req, res) => {
  try {
    const data = req.body || {};
    // ensure schools_attended is JSON
    const schools = Array.isArray(data.schools_attended) ? data.schools_attended : [];

    const cols = [];
    const vals = [];
    const params = [];
    let idx = 1;

    for (const key of Object.keys(data)) {
      if (key === 'schools_attended') continue;
      if (!allowedCols.has(key)) continue;
      cols.push(key);
      vals.push(data[key]);
      params.push(`$${idx}`);
      idx++;
    }

    // add schools_attended jsonb column
    if (schools.length) {
      cols.push('schools_attended');
      vals.push(JSON.stringify(schools));
      params.push(`$${idx}`);
    }

    if (!cols.length) return res.status(400).send('No valid fields provided');

    const q = `INSERT INTO public.newstudents (${cols.join(',')}) VALUES (${params.join(',')}) RETURNING *`;
    console.log('Insert query:', q);
    console.log('Values:', vals);
    const result = await pool.query(q, vals);
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).send(err.message || 'Server error');
  }
});

// record short-course interest clicks / apply attempts
app.post('/api/shortcourse_interest', async (req, res) => {
  try {
    const { school = null, course = null, level = null, price = null, meta = {} } = req.body || {};

    // create table if not exists (safe to run)
    const createTbl = `CREATE TABLE IF NOT EXISTS public.short_course_interests (
      id bigserial PRIMARY KEY,
      school text,
      course text,
      level text,
      price text,
      meta jsonb,
      created_at timestamptz DEFAULT now()
    )`;
    await pool.query(createTbl);

    const insertQ = `INSERT INTO public.short_course_interests (school, course, level, price, meta) VALUES ($1,$2,$3,$4,$5) RETURNING *`;
    const vals = [school, course, level, price, JSON.stringify(meta)];
    const result = await pool.query(insertQ, vals);
    res.json(result.rows[0]);
  } catch (err) {
    console.error('shortcourse_interest error', err);
    res.status(500).send(err.message || 'Server error');
  }
});

app.listen(port, () => {
  console.log(`Server listening on port ${port}`);
});
