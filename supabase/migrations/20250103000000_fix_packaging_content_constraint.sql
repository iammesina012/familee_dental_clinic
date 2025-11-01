-- Fix packaging_content constraint to allow NULL values
-- This allows Piece/Spool/Tub units to have NULL packaging_content

-- Drop the existing constraint
ALTER TABLE supplies 
DROP CONSTRAINT IF EXISTS check_packaging_content_valid;

-- Add new constraint that allows NULL
ALTER TABLE supplies 
ADD CONSTRAINT check_packaging_content_valid 
CHECK (packaging_content IS NULL OR packaging_content IN ('Pieces', 'mL', 'L', 'Cartridge', 'Units', 'Items', 'Count'));

