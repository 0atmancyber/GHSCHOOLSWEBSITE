# Payments Table Update - Respecting New Students Table

## Your Payments Table Structure
```
id (int8) - Primary key
student_id (text) - Foreign key to students table
student_name (text) - Stored for historical reference
student_email (text) - Stored for historical reference  
department (text) - Stored for historical reference
level (text) - Stored for historical reference
amount (numeric) - Payment amount
fee_type (text) - Type of fee (tuition, src dues, etc.)
payment_coverage (text) - Coverage type (full, partial_80, etc.)
coverage_percent (int4) - Coverage percentage
transaction_ref (text) - Transaction reference
receipt_number (text) - Receipt number
payment_date (timestamptz) - Date of payment
status (text) - Payment status
source_table (text) - Source table
source_payload (jsonb) - Original payload
created_at (timestamptz) - Creation timestamp
reference_code (text) - Reference code
phone (varchar) - Phone number
```

## Your Students Table Structure
```
id (int8) - Primary key
student_id (varchar) - Student ID
first_name (varchar) - First name
middle_name (varchar) - Middle name
surname (varchar) - Surname
email (varchar) - Email
phone_number (varchar) - Phone number
whatsapp_number (varchar) - WhatsApp number (optional)
department (varchar) - Department
level (varchar) - Level
created_at (timestamp) - Creation timestamp
updated_at (timestamp) - Update timestamp
```

## Migration Steps

1. **Run the migration** - Execute [payments_table_update_migration.sql](payments_table_update_migration.sql)
   - Adds foreign key constraint
   - Creates indexes for performance
   - Creates views for easy data retrieval

2. **Use the view** - When fetching payments with student data:
   ```sql
   SELECT * FROM payments_with_student_info WHERE student_id = 'GHTS7099';
   ```

3. **Keep storing payment data** - The dashboard will continue to store:
   - student_name, student_email, department, level in payments table
   - This maintains historical accuracy

4. **Fetch fresh data** - When you need current student info:
   - Join payments with students table
   - Use the `payments_with_student_info` view
   - Always prioritize students table as source of truth

## Example Queries

### Get all payments for a student with current student info
```sql
SELECT * FROM payments_with_student_info 
WHERE student_id = 'GHTS7099'
ORDER BY payment_date DESC;
```

### Get payment summary by student
```sql
SELECT * FROM payments_summary_by_student
WHERE department = 'Technology';
```

### Check for data discrepancies
```sql
SELECT * FROM payments p
LEFT JOIN students s ON p.student_id = s.student_id
WHERE p.student_name != (s.first_name || ' ' || s.surname);
```

## What Changed

✅ **Added:**
- Foreign key relationship to students table
- Indexes for performance
- Views for consistent data retrieval
- updated_at timestamp

✅ **Preserved:**
- All historical payment data
- student_name, student_email fields (for audit trail)
- Existing payment logic in dashboard

✅ **Best Practices:**
- Payment records store snapshot of student data
- Students table is source of truth for current info
- Views ensure consistency when joining data

## No Application Code Changes Required

The dashboard code will continue to work as-is because:
- Payment insertion still stores all the fields
- Payment queries still work the same
- Student info lookup uses new students table for fresh data
