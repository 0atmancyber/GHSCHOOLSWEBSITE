const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

// Supabase credentials: prefer environment variables for safety.
// You can set `SUPABASE_URL` and `SUPABASE_KEY` in your environment before running the script.
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://fyriapqeztevzkcaaiqw.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5cmlhcHFlenRldnprY2FhaXF3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM5OTgyNTcsImV4cCI6MjA3OTU3NDI1N30.Re3EZ2VXE6Z7qWhVlxV6yqqIWB8wj1b1wURNLZXpddY';

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function fetchAllNewStudents() {
  try {
    console.log('Fetching all rows from table: newstudents');

    // Request all rows; if your dataset is huge consider using range pagination
    const { data, error } = await supabase
      .from('newstudents')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) throw error;

    const outDir = path.resolve(process.cwd());
    const jsonPath = path.join(outDir, 'newstudents_export.json');
    const csvPath = path.join(outDir, 'newstudents_export.csv');

    fs.writeFileSync(jsonPath, JSON.stringify(data, null, 2), 'utf8');
    console.log('Wrote', jsonPath);

    // Convert to CSV
    if (Array.isArray(data) && data.length > 0) {
      const headers = Object.keys(data[0]);
      const rows = data.map(row => headers.map(h => {
        const val = row[h] === null || row[h] === undefined ? '' : row[h];
        // Escape quotes
        return String(val).replace(/"/g, '""');
      }).map(v => `"${v}"`).join(','));

      const csv = [headers.join(','), ...rows].join('\n');
      fs.writeFileSync(csvPath, csv, 'utf8');
      console.log('Wrote', csvPath);
    } else {
      fs.writeFileSync(csvPath, '', 'utf8');
      console.log('No rows found; created empty', csvPath);
    }

    console.log('Fetch complete. Rows fetched:', Array.isArray(data) ? data.length : 0);
    return data;
  } catch (err) {
    console.error('Error fetching newstudents:', err.message || err);
    process.exitCode = 1;
    return null;
  }
}

// Run when executed directly
if (require.main === module) {
  fetchAllNewStudents();
}

module.exports = { fetchAllNewStudents };
