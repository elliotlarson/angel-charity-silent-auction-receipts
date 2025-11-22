# Extract expiration dates and special notes from descriptions

Many auction item descriptions contain important information that should be extracted into separate fields for better organization and display on receipts. This includes expiration dates and special instructions/notes.

## Task

Manually process the auction items CSV file using AI to extract:

1. **Expiration dates** - Many items have expiration information embedded in their descriptions:
   - "Expires on 12/31/2026"
   - "Certificate must be redeemed by June 1, 2027"
   - "No expiration date"

2. **Special notes** - Important information that should be highlighted:
   - Contact information for booking/redemption
   - Restrictions or limitations
   - Scheduling requirements
   - Location restrictions
   - Special instructions

## Approach

This will be done through **manual AI processing** rather than automated code:

1. Use AI tools to analyze each description
2. Extract expiration dates and special notes
3. Add two new columns to the source CSV:
   - `expiration_date` - Standardized date format or "No expiration"
   - `special_notes` - Consolidated important instructions/restrictions

4. Update the CSV processor to include these new fields
5. Regenerate the JSON files with the new fields

## Examples

**Item 105:**
- Current: "...expires 12/31/2026). Out of town charges apply if more than 20 miles from Central Tucson."
- `expiration_date`: "12/31/2026"
- `special_notes`: "Out of town charges apply if more than 20 miles from Central Tucson"

**Item 111:**
- Current: "Certificate must be redeemed by June 1, 2027. To process, please contact Gracie Quiroz Marum at 520-838-2571."
- `expiration_date`: "June 1, 2027"
- `special_notes`: "To process, please contact Gracie Quiroz Marum at 520-838-2571"

**Item 116:**
- Current: "Please book your experience by contacting Jessica Marshall, Estate House Manager @ (707)204-0037 or jessica@baldaccivineyards.com. Expires on 12/31/2026."
- `expiration_date`: "12/31/2026"
- `special_notes`: "Contact Jessica Marshall at (707)204-0037 or jessica@baldaccivineyards.com to book"

## Deliverable

Updated CSV file with two new columns (`expiration_date` and `special_notes`) populated for all applicable auction items.
