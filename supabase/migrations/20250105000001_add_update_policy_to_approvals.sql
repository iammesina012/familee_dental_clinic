-- Add UPDATE policy for stock_deduction_approvals table
-- This allows authenticated users to update approval status (approve/reject)

CREATE POLICY "Authenticated users can update approvals"
  ON stock_deduction_approvals
  FOR UPDATE
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

