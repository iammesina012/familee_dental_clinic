-- Create table to store stock deduction approvals from Service Management
CREATE TABLE IF NOT EXISTS stock_deduction_approvals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  preset_name TEXT NOT NULL,
  supplies JSONB NOT NULL,
  patient_name TEXT NOT NULL,
  age TEXT NOT NULL,
  gender TEXT NOT NULL,
  conditions TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index for efficient queries by creation date
CREATE INDEX IF NOT EXISTS idx_approvals_created_at ON stock_deduction_approvals(created_at DESC);

-- Create index for efficient queries by preset name
CREATE INDEX IF NOT EXISTS idx_approvals_preset_name ON stock_deduction_approvals(preset_name);

-- Enable Row Level Security
ALTER TABLE stock_deduction_approvals ENABLE ROW LEVEL SECURITY;

-- Create policy: Authenticated users can read all approvals
CREATE POLICY "Authenticated users can view approvals"
  ON stock_deduction_approvals
  FOR SELECT
  USING (auth.role() = 'authenticated');

-- Create policy: Authenticated users can insert approvals
CREATE POLICY "Authenticated users can insert approvals"
  ON stock_deduction_approvals
  FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- Create policy: Authenticated users can delete approvals
CREATE POLICY "Authenticated users can delete approvals"
  ON stock_deduction_approvals
  FOR DELETE
  USING (auth.role() = 'authenticated');

-- Create policy: Service role can do everything (for edge functions)
CREATE POLICY "Service role has full access"
  ON stock_deduction_approvals
  FOR ALL
  USING (auth.jwt()->>'role' = 'service_role');

-- Add comment
COMMENT ON TABLE stock_deduction_approvals IS 'Stores pending stock deduction approvals from Service Management presets with patient information';

