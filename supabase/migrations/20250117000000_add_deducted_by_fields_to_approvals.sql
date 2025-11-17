-- Add deducted_by and deducted_by_name fields to stock_deduction_approvals table
ALTER TABLE stock_deduction_approvals 
ADD COLUMN IF NOT EXISTS deducted_by UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS deducted_by_name TEXT;

-- Create index for efficient queries by deducted_by
CREATE INDEX IF NOT EXISTS idx_approvals_deducted_by ON stock_deduction_approvals(deducted_by);

-- Update comment
COMMENT ON COLUMN stock_deduction_approvals.deducted_by IS 'User ID who created the deduction request';
COMMENT ON COLUMN stock_deduction_approvals.deducted_by_name IS 'Display name of the user who created the deduction request';

