-- Add status field to stock_deduction_approvals table
ALTER TABLE stock_deduction_approvals 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected'));

-- Create index for efficient queries by status
CREATE INDEX IF NOT EXISTS idx_approvals_status ON stock_deduction_approvals(status);

-- Update existing records to have 'pending' status
UPDATE stock_deduction_approvals 
SET status = 'pending' 
WHERE status IS NULL;

