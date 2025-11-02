-- Add from_deduction field to stock_deduction_presets table
-- This field marks presets that were created from approved deductions (shown in Deduction Logs)

ALTER TABLE stock_deduction_presets
ADD COLUMN IF NOT EXISTS from_deduction BOOLEAN DEFAULT false;

-- Add comment for documentation
COMMENT ON COLUMN stock_deduction_presets.from_deduction IS 'Marks presets created from approved deductions (shown in Deduction Logs page)';

