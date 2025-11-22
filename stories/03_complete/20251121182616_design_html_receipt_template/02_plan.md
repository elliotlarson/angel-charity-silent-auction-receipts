# Implementation Plan: HTML Receipt Template for Auction Items

## Progress Checklist

- [x] Step 1: Create initial HTML receipt template with Tailwind CSS
- [x] Step 2: Add Angel Charity logo and header section
- [x] Step 3: Add auction item data display section
- [x] Step 4: Add signature and receipt information section
- [x] Step 5: Style and finalize the receipt layout

## Overview

We're creating a professional HTML receipt template for the Angel Charity 2025 Angel Ball Silent Auction. The receipt will be used to generate PDFs for auction item winners. The design will use Tailwind CSS 4.x (via CDN) for styling and will be iterative in nature, allowing for design refinements.

## Key Design Decisions

- **Tailwind CSS 4.x via CDN**: Using the latest Tailwind CSS from CDN for easy iteration without build steps
- **Standalone HTML file**: Creating a self-contained `index.html` in the story directory for easy viewing and testing
- **Print-friendly design**: Designing with PDF generation in mind (clean layout, good contrast, professional styling)
- **Embedded SVG logo**: Including the Angel Charity logo directly in the HTML template
- **Sample data**: Initially using hardcoded sample data from one of the actual auction items to demonstrate the design

## Implementation Steps

### Step 1: Create initial HTML receipt template with Tailwind CSS

**Files to create:**

- `stories/02_working/20251121182616_design_html_receipt_template/index.html`

**Changes:**

1. Create a basic HTML5 document structure
2. Include Tailwind CSS 4.x from CDN in the `<head>`
3. Set up a basic page layout with centered content
4. Add a simple container for the receipt with white background and shadow

**Code structure:**

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Angel Charity - Auction Receipt</title>
  <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-100 p-8">
  <div class="max-w-3xl mx-auto bg-white shadow-lg p-8">
    <!-- Receipt content will go here -->
    <h1 class="text-2xl font-bold text-center">Angel Charity Receipt</h1>
  </div>
</body>
</html>
```

**Commit message:** `Create initial HTML receipt template structure`

---

### Step 2: Add Angel Charity logo and header section

**Files to modify:**

- `stories/02_working/20251121182616_design_html_receipt_template/index.html`

**Files to read:**

- `stories/02_working/20251121182616_design_html_receipt_template/angel_charity_logo.svg`
- `stories/02_working/20251121182616_design_html_receipt_template/angel_charity_info.json`

**Changes:**

1. Read the SVG logo file and embed it inline in the HTML (within a reasonable size, e.g., max-width of 200px)
2. Add Angel Charity organization information from the JSON file:
   - Organization name
   - Address: 3132 N. Swan Rd., Tucson, Arizona 85712
   - Email: info@AngelCharity.org
   - Phone: 520-326-3686
3. Add the event information: "2025 Angel Ball Silent Auction - December 13, 2025"
4. Style the header section with proper spacing and typography

**Code approach:**

```html
<div class="text-center mb-8">
  <!-- SVG logo embedded inline -->
  <div class="mb-4">
    <!-- Logo SVG here -->
  </div>

  <h1 class="text-3xl font-bold mb-2">Angel Charity for Children</h1>
  <p class="text-sm text-gray-600">3132 N. Swan Rd., Tucson, Arizona 85712</p>
  <p class="text-sm text-gray-600">520-326-3686 | info@AngelCharity.org</p>

  <div class="mt-6 pt-6 border-t border-gray-300">
    <h2 class="text-xl font-semibold">2025 Angel Ball Silent Auction</h2>
    <p class="text-gray-600">December 13, 2025</p>
  </div>
</div>
```

**Commit message:** `Add Angel Charity logo and header section`

---

### Step 3: Add auction item data display section

**Files to modify:**

- `stories/02_working/20251121182616_design_html_receipt_template/index.html`

**Changes:**

1. Add a section for auction item details using sample data (e.g., the landscaping item #103)
2. Display the following fields with clear labels:
   - Item ID and Title
   - Description (HTML formatted)
   - Fair Market Value (formatted as currency)
   - Special Notes (if present)
   - Expiration Notice (if present)
3. Style using appropriate Tailwind classes for readability

**Code approach:**

```html
<div class="mb-8">
  <h3 class="text-lg font-semibold mb-4 pb-2 border-b border-gray-300">Auction Item Details</h3>

  <div class="mb-4">
    <p class="text-sm text-gray-600">Item #103</p>
    <h4 class="text-xl font-bold">One Year Monthly Landscaping Services</h4>
    <p class="text-sm text-gray-600 italic">Landscaping</p>
  </div>

  <div class="mb-4">
    <h5 class="font-semibold text-sm uppercase text-gray-700 mb-1">Description</h5>
    <div class="text-gray-800 text-sm">
      <!-- HTML description content -->
    </div>
  </div>

  <div class="mb-4">
    <h5 class="font-semibold text-sm uppercase text-gray-700 mb-1">Fair Market Value</h5>
    <p class="text-lg font-bold">$1,200.00</p>
  </div>

  <div class="mb-4">
    <h5 class="font-semibold text-sm uppercase text-gray-700 mb-1">Special Notes</h5>
    <p class="text-sm text-gray-800">Good for any home in the Tucson, Oro Valley, or Marana area.</p>
  </div>

  <div class="mb-4">
    <h5 class="font-semibold text-sm uppercase text-gray-700 mb-1">Expiration</h5>
    <p class="text-sm text-gray-800">No expiration date.</p>
  </div>
</div>
```

**Commit message:** `Add auction item details display section`

---

### Step 4: Add signature and receipt information section

**Files to modify:**

- `stories/02_working/20251121182616_design_html_receipt_template/index.html`

**Changes:**

1. Add fields for recipient signature information:
   - Signature line with space above for actual signature
   - Printed name line
   - Date of receipt line
2. Add appropriate labels and styling
3. Include sufficient spacing for handwritten signatures
4. Add a footer with thank you message

**Code approach:**

```html
<div class="mt-12 pt-8 border-t border-gray-300">
  <h3 class="text-lg font-semibold mb-6">Receipt Acknowledgment</h3>

  <div class="space-y-8">
    <div>
      <label class="block text-sm font-semibold text-gray-700 mb-2">Signature</label>
      <div class="border-b-2 border-gray-400 pb-1 mb-1" style="min-height: 50px;"></div>
    </div>

    <div>
      <label class="block text-sm font-semibold text-gray-700 mb-2">Printed Name</label>
      <div class="border-b-2 border-gray-400 pb-1"></div>
    </div>

    <div>
      <label class="block text-sm font-semibold text-gray-700 mb-2">Date</label>
      <div class="border-b-2 border-gray-400 pb-1 max-w-xs"></div>
    </div>
  </div>

  <div class="mt-12 text-center text-sm text-gray-600">
    <p>Thank you for supporting Angel Charity for Children!</p>
  </div>
</div>
```

**Commit message:** `Add signature and receipt acknowledgment section`

---

### Step 5: Style and finalize the receipt layout

**Files to modify:**

- `stories/02_working/20251121182616_design_html_receipt_template/index.html`

**Changes:**

1. Review the overall layout and make styling refinements
2. Ensure consistent spacing and typography throughout
3. Add any final touches for print/PDF friendliness:
   - Ensure good contrast for printing
   - Set appropriate page margins
   - Add print media queries if needed
4. Verify the receipt looks professional and complete
5. Test opening the file in a browser

**Testing:**

- Open `index.html` in a web browser
- Review the visual appearance
- Use browser print preview to see how it will look as a PDF

**Commit message:** `Finalize receipt styling and layout`

---

## Notes

- The HTML file will be self-contained in the story directory for easy iteration
- The design can be refined based on visual review after each step
- Sample data from item #103 (landscaping) will be used initially
- The template is designed to be easily convertible to a dynamic template in the future
- All content uses standard UTF-8 characters only
