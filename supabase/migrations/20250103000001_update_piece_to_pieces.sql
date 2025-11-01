-- Update packaging_unit constraint to change 'Piece' to 'Pieces'

-- Drop the existing constraint
ALTER TABLE supplies 
DROP CONSTRAINT IF EXISTS check_packaging_unit_valid;

-- Add new constraint with 'Pieces' instead of 'Piece'
ALTER TABLE supplies 
ADD CONSTRAINT check_packaging_unit_valid 
CHECK (packaging_unit IN ('Pack', 'Box', 'Bottle', 'Jug', 'Pad', 'Pieces', 'Spool', 'Tub'));

-- Update existing data from 'Piece' to 'Pieces'
UPDATE supplies 
SET packaging_unit = 'Pieces' 
WHERE packaging_unit = 'Piece';

