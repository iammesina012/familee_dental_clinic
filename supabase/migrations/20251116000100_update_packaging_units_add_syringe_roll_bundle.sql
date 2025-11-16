-- Allow new packaging units: Syringe, Roll, Bundle
-- Also keep existing units including the earlier switch from 'Piece' to 'Pieces'

ALTER TABLE supplies
  DROP CONSTRAINT IF EXISTS check_packaging_unit_valid;

ALTER TABLE supplies
  ADD CONSTRAINT check_packaging_unit_valid
  CHECK (packaging_unit IN (
    'Pack',
    'Box',
    'Bundle',
    'Bottle',
    'Jug',
    'Pad',
    'Pieces',
    'Spool',
    'Tub',
    'Syringe',
    'Roll'
  ));


