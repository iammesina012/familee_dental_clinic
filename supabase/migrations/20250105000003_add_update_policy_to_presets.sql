-- Add UPDATE policy for stock_deduction_presets table
-- This allows authenticated users to update preset information

CREATE POLICY "Authenticated users can update presets"
  ON stock_deduction_presets
  FOR UPDATE
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

