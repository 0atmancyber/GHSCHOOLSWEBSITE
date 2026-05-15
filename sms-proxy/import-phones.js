/*
  import-phones.js
  Reads a CSV and upserts phone numbers into Supabase `student_master_db` table.

  Expected CSV format (header required):
    student_id,phone

  Usage:
    1. In sms-proxy folder, install deps:
       npm install @supabase/supabase-js csv-parse dotenv
    2. Create a .env with SUPABASE_URL and SUPABASE_SERVICE_KEY (service_role key)
    3. Run:
       node import-phones.js sample_phones.csv
*/

const fs = require('fs');
const path = require('path');
const { parse } = require('csv-parse/sync');
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

async function main(){
  const argv = process.argv.slice(2);
  if(argv.length === 0){
    console.error('Usage: node import-phones.js <csv-file>');
    process.exit(2);
  }

  const csvPath = path.resolve(process.cwd(), argv[0]);
  if(!fs.existsSync(csvPath)){
    console.error('CSV file not found:', csvPath);
    process.exit(2);
  }

  const SUPABASE_URL = process.env.SUPABASE_URL;
  const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
  if(!SUPABASE_URL || !SUPABASE_SERVICE_KEY){
    console.error('Please set SUPABASE_URL and SUPABASE_SERVICE_KEY in your .env');
    process.exit(2);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, { auth: { persistSession: false } });

  const content = fs.readFileSync(csvPath, 'utf8');
  let records;
  try {
    records = parse(content, { columns: true, skip_empty_lines: true });
  } catch (e) {
    console.error('Failed to parse CSV:', e.message || e);
    process.exit(2);
  }

  // Map to upsert rows
  const rows = records.map(r => {
    // normalize column names
    const student_id = (r.student_id || r.studentId || r['Student ID'] || '').toString().trim();
    const phoneRaw = (r.phone || r.phone_number || r.phoneNumber || r.phoneNumber || '').toString().trim();
    // simple normalization: remove non-digits, convert leading 0 to 233
    let digits = phoneRaw.replace(/\D/g, '');
    if(digits.startsWith('0')) digits = '233' + digits.slice(1);
    return { student_id, phone_number_1: digits };
  }).filter(r => r.student_id && r.phone_number_1);

  if(rows.length === 0){
    console.error('No valid rows found in CSV (need student_id and phone)');
    process.exit(2);
  }

  console.log(`Preparing to upsert ${rows.length} rows into student_master_db (phone update).`);

  // Batch upserts in chunks to avoid payload limits
  const chunkSize = 500;
  for(let i=0;i<rows.length;i+=chunkSize){
    const chunk = rows.slice(i, i+chunkSize);
    try{
      // Upsert on student_id; this will insert new rows if they don't exist or update phone if student exists
      const { data, error } = await supabase.from('student_master_db').upsert(chunk, { onConflict: ['student_id'] }).select('student_id,phone_number_1');
      if(error){
        console.error('Supabase upsert error for chunk starting at', i, error.message || error);
      } else {
        console.log(`Upserted ${data && data.length ? data.length : chunk.length} rows (chunk ${i}/${rows.length})`);
      }
    }catch(e){
      console.error('Error while upserting chunk starting at', i, e.message || e);
    }
  }

  console.log('Import complete.');
}

main();
