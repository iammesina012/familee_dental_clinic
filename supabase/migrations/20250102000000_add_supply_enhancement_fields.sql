-- Add new fields to supplies table for enhanced supply management
-- This migration adds fields for type, packaging details, and other enhancements

-- Add new columns to supplies table
ALTER TABLE supplies 
ADD COLUMN IF NOT EXISTS type TEXT,
ADD COLUMN IF NOT EXISTS packaging_unit TEXT,
ADD COLUMN IF NOT EXISTS packaging_quantity INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS packaging_content TEXT,
ADD COLUMN IF NOT EXISTS packaging_content_quantity INTEGER DEFAULT 1;

-- Add comments for documentation
COMMENT ON COLUMN supplies.type IS 'Type/specification of the supply item (e.g., "Blue Surgical Mask", "Latex Gloves")';
COMMENT ON COLUMN supplies.packaging_unit IS 'Primary packaging unit (Box, Piece, Pack)';
COMMENT ON COLUMN supplies.packaging_quantity IS 'Quantity of primary packaging units';
COMMENT ON COLUMN supplies.packaging_content IS 'Content type within packaging (Pieces, Units, Items, Count)';
COMMENT ON COLUMN supplies.packaging_content_quantity IS 'Quantity of content within each packaging unit';

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_supplies_type ON supplies(type);
CREATE INDEX IF NOT EXISTS idx_supplies_packaging_unit ON supplies(packaging_unit);
CREATE INDEX IF NOT EXISTS idx_supplies_packaging_content ON supplies(packaging_content);

-- Update existing records to have default values for new fields
UPDATE supplies 
SET 
  type = COALESCE(type, ''),
  packaging_unit = COALESCE(packaging_unit, 'Box'),
  packaging_quantity = COALESCE(packaging_quantity, 1),
  packaging_content = COALESCE(packaging_content, 'Pieces'),
  packaging_content_quantity = COALESCE(packaging_content_quantity, 1)
WHERE 
  type IS NULL 
  OR packaging_unit IS NULL 
  OR packaging_quantity IS NULL 
  OR packaging_content IS NULL 
  OR packaging_content_quantity IS NULL;

-- Add constraints to ensure data integrity
ALTER TABLE supplies 
ALTER COLUMN packaging_quantity SET NOT NULL,
ALTER COLUMN packaging_content_quantity SET NOT NULL;

-- Add check constraints for valid values
ALTER TABLE supplies 
ADD CONSTRAINT check_packaging_quantity_positive 
CHECK (packaging_quantity >= 1);

ALTER TABLE supplies 
ADD CONSTRAINT check_packaging_content_quantity_positive 
CHECK (packaging_content_quantity >= 1);

-- Add check constraint for valid packaging units
ALTER TABLE supplies 
ADD CONSTRAINT check_packaging_unit_valid 
CHECK (packaging_unit IN ('Pack', 'Box', 'Bottle', 'Jug', 'Pad', 'Piece', 'Spool', 'Tub'));

-- Add check constraint for valid packaging content types
ALTER TABLE supplies 
ADD CONSTRAINT check_packaging_content_valid 
CHECK (packaging_content IN ('Pieces', 'mL', 'L', 'Cartridge', 'Units', 'Items', 'Count'));
