-- Add patient information fields to stock_deduction_presets table
-- These fields will store patient data when approval is rejected
-- and will be cleared when approval is approved

ALTER TABLE stock_deduction_presets
ADD COLUMN IF NOT EXISTS patient_name TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS age TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS gender TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS conditions TEXT DEFAULT '';

-- Add comments for documentation
COMMENT ON COLUMN stock_deduction_presets.patient_name IS 'Patient name (stored when approval is rejected)';
COMMENT ON COLUMN stock_deduction_presets.age IS 'Patient age (stored when approval is rejected)';
COMMENT ON COLUMN stock_deduction_presets.gender IS 'Patient gender (stored when approval is rejected)';
COMMENT ON COLUMN stock_deduction_presets.conditions IS 'Patient conditions (stored when approval is rejected)';

