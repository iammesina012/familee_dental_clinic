-- Add purpose and remarks fields to stock_deduction_approvals table for direct deductions
ALTER TABLE stock_deduction_approvals 
ADD COLUMN IF NOT EXISTS purpose TEXT,
ADD COLUMN IF NOT EXISTS remarks TEXT;

-- Create index for efficient queries by purpose
CREATE INDEX IF NOT EXISTS idx_approvals_purpose ON stock_deduction_approvals(purpose);

-- Update comment
COMMENT ON COLUMN stock_deduction_approvals.purpose IS 'Purpose of stock deduction (for direct deductions from stock deduction page)';
COMMENT ON COLUMN stock_deduction_approvals.remarks IS 'Additional remarks for stock deduction';

