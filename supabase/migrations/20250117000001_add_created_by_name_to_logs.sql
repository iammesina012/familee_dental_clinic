-- Add created_by_name field to stock_deduction_logs table
ALTER TABLE stock_deduction_logs 
ADD COLUMN IF NOT EXISTS created_by_name TEXT;

-- Create index for efficient queries by created_by_name
CREATE INDEX IF NOT EXISTS idx_logs_created_by_name ON stock_deduction_logs(created_by_name);

-- Update comment
COMMENT ON COLUMN stock_deduction_logs.created_by_name IS 'Display name of the user who created the deduction log';

