# Stock Deduction Automation Analysis - Packaging Unit Conversion

## Executive Summary

This document analyzes the current inventory workflow and proposes automation solutions for handling Packaging Units and Packaging Content conversions in the Stock Deduction page, specifically for the Service Management field.

## Current System Understanding

### Inventory Structure

1. **Packaging Unit** (e.g., Box, Pack, Bottle):
   - Primary container unit
   - Stored in `packaging_unit` field

2. **Packaging Content** (e.g., Pieces, mL, L):
   - Content inside each Packaging Unit
   - Stored in `packaging_content` field
   - Quantity stored in `packaging_content_quantity` (e.g., 100 pieces per box)

3. **Stock Field**:
   - Represents quantity in **Packaging Units**
   - Example: `stock = 5` means 5 Boxes
   - Each box contains `packaging_content_quantity` pieces (e.g., 100 pieces)

### Current Deduction Workflow

1. **Service Management Preset Creation**:
   - Users specify supplies with a `quantity` field
   - Currently, `quantity` is interpreted as Packaging Units
   - No distinction between Packaging Units and Packaging Content

2. **Stock Deduction Process**:
   - When loading a preset, `preset['quantity']` is directly used as `deductQty`
   - The `applyDeductions` method subtracts `deductQty` from `stock`
   - **Problem**: If preset quantity is 4 (intended as 4 pieces), it deducts 4 Boxes instead

3. **The Gap**:
   ```
   Example Scenario:
   - Inventory: 5 Boxes of Masks
   - Each Box: 100 Pieces
   - Total Stock: 500 Pieces (but stored as 5 Boxes)
   
   User wants to deduct: 4 Pieces
   Current behavior: Deducts 4 Boxes (400 pieces) ❌
   Expected behavior: Deduct 0.04 Boxes → Handle intelligently ✅
   ```

## Proposed Automation Solutions

### Solution 1: Dual-Mode Quantity Input (Recommended)

**Description**: Add a unit selector for each supply in Service Management presets, allowing users to choose whether they're entering quantities in Packaging Units or Packaging Content.

#### Implementation Details:

1. **Preset Creation/Edit Pages**:
   - Add a toggle/dropdown: "Quantity Unit: [Packaging Unit] or [Packaging Content]"
   - Store this preference in the preset: `quantity_unit: 'packaging_unit' | 'packaging_content'`
   - Display current unit clearly: "4 Boxes" vs "4 Pieces"

2. **Preset Data Structure**:
   ```dart
   {
     'name': 'Supply Name',
     'quantity': 4,
     'quantity_unit': 'packaging_content', // NEW FIELD
     'packaging_unit': 'Box',
     'packaging_content': 'Pieces',
     'packaging_content_quantity': 100
   }
   ```

3. **Conversion Logic** (when loading preset):
   ```dart
   int convertToPackagingUnits({
     required int quantity,
     required String quantityUnit,
     int? packagingContentQuantity,
   }) {
     if (quantityUnit == 'packaging_unit' || packagingContentQuantity == null) {
       return quantity; // Already in packaging units
     }
     
     // Convert packaging content to packaging units
     // Example: 4 pieces / 100 pieces per box = 0.04 boxes
     double result = quantity / packagingContentQuantity;
     
     // Round up to nearest whole box if user wants complete boxes
     // OR handle partial boxes based on business logic
     return result.ceil(); // Round up (safer for inventory)
     // OR return result.floor(); // Round down (more precise)
   }
   ```

4. **UI Display**:
   - Show both units: "4 Pieces (0.04 Boxes)" or "1 Box (100 Pieces)"
   - Show conversion warning if partial boxes are involved

#### Benefits:
- ✅ Clear user intent
- ✅ Flexible for different use cases
- ✅ Prevents accidental over-deduction

#### Drawbacks:
- Requires preset migration (add default `quantity_unit: 'packaging_unit'`)

---

### Solution 2: Automatic Content-Based Conversion

**Description**: Automatically detect and convert Packaging Content quantities to Packaging Units when loading presets.

#### Implementation Details:

1. **Detection Logic**:
   - When loading a preset, check if `quantity` value makes sense as Packaging Content
   - If quantity < `packaging_content_quantity`, assume it's Packaging Content
   - Example: If quantity is 4 and packaging_content_quantity is 100, treat as 4 pieces

2. **Conversion in `_loadPresetIntoDeductions`**:
   ```dart
   Future<void> _loadPresetIntoDeductions(Map<String, dynamic> preset) async {
     // ... existing code ...
     
     for (final supply in supplies) {
       final int presetQuantity = (supply['quantity'] ?? 1) as int;
       final int? packagingContentQty = primaryBatch.packagingContentQuantity;
       final String? packagingUnit = primaryBatch.packagingUnit;
       final String? packagingContent = primaryBatch.packagingContent;
       
       int deductQtyInPackagingUnits = presetQuantity;
       
       // Auto-convert if quantity seems like Packaging Content
       if (packagingContentQty != null && 
           packagingContentQty > 0 &&
           packagingUnit != null &&
           presetQuantity < packagingContentQty) {
         
         // Convert: pieces to boxes
         double boxesNeeded = presetQuantity / packagingContentQty;
         deductQtyInPackagingUnits = boxesNeeded.ceil(); // Round up to whole boxes
         
         // Show conversion info to user
         print('Auto-converted: $presetQuantity $packagingContent → ${deductQtyInPackagingUnits} $packagingUnit');
       }
       
       final int finalDeductQty = deductQtyInPackagingUnits > primaryBatch.stock
           ? primaryBatch.stock
           : deductQtyInPackagingUnits;
       
       // ... rest of code ...
     }
   }
   ```

3. **Smart Partial Box Handling**:
   ```dart
   // Option A: Round up (deduct complete boxes)
   int boxesToDeduct = (pieces / piecesPerBox).ceil();
   
   // Option B: Track partial boxes separately (complex)
   // Option C: Always deduct whole boxes, show remaining pieces
   ```

#### Benefits:
- ✅ Automatic, no user input needed
- ✅ Works with existing presets
- ✅ Prevents confusion

#### Drawbacks:
- ⚠️ May incorrectly interpret large quantities
- ⚠️ Ambiguous when quantity equals packaging_content_quantity

---

### Solution 3: Hybrid Approach with UI Indicators (Best UX)

**Description**: Combine automatic detection with clear UI indicators and optional manual override.

#### Implementation Details:

1. **In Preset Creation/Edit**:
   - Show packaging info: "1 Box = 100 Pieces"
   - Display quantity with both units dynamically
   - Add helper text: "Enter quantity in Boxes or Pieces"

2. **Quantity Input Enhancement**:
   ```dart
   Widget _buildQuantityInput(int index) {
     final supply = _presetSupplies[index];
     final packagingUnit = supply['packagingUnit'] ?? 'Box';
     final packagingContent = supply['packagingContent'] ?? 'Pieces';
     final contentQty = supply['packagingContentQuantity'] ?? 1;
     
     return Column(
       children: [
         Row(
           children: [
             Expanded(
               child: TextField(
                 // Quantity input
               ),
             ),
             DropdownButton(
               items: [
                 DropdownMenuItem(value: 'unit', child: Text(packagingUnit)),
                 DropdownMenuItem(value: 'content', child: Text(packagingContent)),
               ],
               value: supply['quantity_unit'] ?? 'unit',
               onChanged: (value) {
                 // Update quantity_unit
               },
             ),
           ],
         ),
         Text(
           supply['quantity_unit'] == 'content'
             ? '${supply['quantity']} $packagingContent = ${(supply['quantity'] / contentQty).ceil()} $packagingUnit'
             : '${supply['quantity']} $packagingUnit = ${supply['quantity'] * contentQty} $packagingContent',
           style: TextStyle(color: Colors.grey),
         ),
       ],
     );
   }
   ```

3. **In Stock Deduction Page**:
   - Show conversion clearly: "4 Pieces (0.04 Boxes)"
   - Display warning for partial boxes: "Will deduct 1 Box (100 pieces)"
   - Allow manual adjustment before deduction

4. **Conversion Service**:
   ```dart
   class PackagingConverter {
     /// Convert quantity based on unit type
     static int convertToPackagingUnits({
       required int quantity,
       required String quantityUnit,
       required int packagingContentQuantity,
     }) {
       if (quantityUnit == 'packaging_unit') {
         return quantity;
       }
       
       // Convert packaging content to units (round up for safety)
       return (quantity / packagingContentQuantity).ceil();
     }
     
     /// Get display string showing both units
     static String getDisplayString({
       required int quantity,
       required String quantityUnit,
       required String packagingUnit,
       required String packagingContent,
       required int packagingContentQuantity,
     }) {
       if (quantityUnit == 'packaging_unit') {
         final totalContent = quantity * packagingContentQuantity;
         return '$quantity $packagingUnit ($totalContent $packagingContent)';
       } else {
         final boxesNeeded = (quantity / packagingContentQuantity).ceil();
         return '$quantity $packagingContent ($boxesNeeded $packagingUnit)';
       }
     }
   }
   ```

#### Benefits:
- ✅ Best user experience
- ✅ Clear, transparent conversions
- ✅ Flexible and safe
- ✅ Prevents errors

---

## Recommended Implementation Plan

### Phase 1: Core Conversion Logic
1. Create `PackagingConverter` utility class
2. Update preset data model to include `quantity_unit`
3. Implement conversion in `_loadPresetIntoDeductions`

### Phase 2: UI Enhancements
1. Add unit selector in preset creation/edit pages
2. Update Stock Deduction page to show conversions
3. Add validation and warnings

### Phase 3: Advanced Features
1. Handle partial boxes intelligently
2. Track remaining pieces per box
3. Add bulk conversion options

## Code Changes Required

### 1. Add PackagingConverter Service
**File**: `lib/features/stock_deduction/services/packaging_converter.dart`
```dart
class PackagingConverter {
  static int convertToPackagingUnits({
    required int quantity,
    required String quantityUnit,
    required int packagingContentQuantity,
  }) {
    if (quantityUnit == 'packaging_unit' || packagingContentQuantity <= 0) {
      return quantity;
    }
    return (quantity / packagingContentQuantity).ceil();
  }
  
  static String getConversionDisplay({
    required int quantity,
    required String quantityUnit,
    required String packagingUnit,
    required String packagingContent,
    required int packagingContentQuantity,
  }) {
    if (quantityUnit == 'packaging_unit') {
      final totalContent = quantity * packagingContentQuantity;
      return '$quantity $packagingUnit ($totalContent $packagingContent)';
    } else {
      final boxesNeeded = (quantity / packagingContentQuantity).ceil();
      final totalInBox = boxesNeeded * packagingContentQuantity;
      return '$quantity $packagingContent (≈ $boxesNeeded $packagingUnit)';
    }
  }
}
```

### 2. Update Preset Loading Logic
**File**: `lib/features/stock_deduction/pages/stock_deduction_page.dart`
- Modify `_loadPresetIntoDeductions` to use `PackagingConverter`
- Include packaging info in deduction items
- Display conversions in UI

### 3. Enhance Preset UI
**Files**: 
- `lib/features/stock_deduction/pages/sd_create_preset_page.dart`
- `lib/features/stock_deduction/pages/sd_edit_preset_page.dart`
- Add unit selector and conversion display

## Example Workflow After Implementation

### Scenario: Deduct 4 Pieces from 1 Box (100 pieces per box)

**Step 1: Create Preset**
- Supply: "Surgical Masks"
- Quantity: 4
- Unit: "Pieces" (selected from dropdown)
- Display: "4 Pieces (≈ 1 Box)"

**Step 2: Load Preset**
- System detects: 4 Pieces → needs 0.04 Boxes
- Rounds up to: 1 Box
- Shows: "Will deduct: 4 Pieces (1 Box containing 100 pieces)"
- Warning: "Deducting 1 Box (96 pieces remaining unused)"

**Step 3: Apply Deduction**
- Deducts: 1 Box from inventory
- Stock updated: 4 Boxes → 3 Boxes
- Logged: "4 Pieces deducted (1 Box)"

## Edge Cases to Handle

1. **Partial Boxes**: Round up vs Round down policy
2. **Missing Packaging Info**: Default to Packaging Units
3. **Zero Packaging Content**: Handle gracefully
4. **Multiple Batches**: Apply FIFO with conversions
5. **Insufficient Stock**: Clear error messages with conversions

## Conclusion

The **Hybrid Approach (Solution 3)** provides the best balance of automation and user control. It automatically handles conversions while giving users visibility and control over the process. The implementation should prioritize clarity and safety to prevent accidental over-deduction of inventory.

