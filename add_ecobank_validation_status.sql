-- Migration: Add ecobank_validation_status column to payments table
-- Purpose: Track which bank validation records have been used
-- Values: 'unused' or 'used'
-- Default: 'unused' (all existing records are initially unused)

-- Add column to payments table
ALTER TABLE payments
ADD COLUMN IF NOT EXISTS ecobank_validation_status text DEFAULT 'unused';

-- Create index for performance (frequently queried when filtering unused validations)
CREATE INDEX IF NOT EXISTS idx_payments_ecobank_validation_status 
  ON payments(student_id, ecobank_validation_status) 
  WHERE ecobank_validation_status = 'unused';

-- Optional: Create index for transaction_ref to speed up linking validations to payment rows
CREATE INDEX IF NOT EXISTS idx_payments_transaction_ref_status 
  ON payments(transaction_ref, ecobank_validation_status);
