-- Add phone column to payments table
ALTER TABLE payments ADD COLUMN IF NOT EXISTS phone VARCHAR(20);

-- Add phone column to level100payments table
ALTER TABLE level100payments ADD COLUMN IF NOT EXISTS phone VARCHAR(20);

-- Add index on phone for faster searches
CREATE INDEX IF NOT EXISTS idx_payments_phone ON payments(phone);
CREATE INDEX IF NOT EXISTS idx_level100payments_phone ON level100payments(phone);
