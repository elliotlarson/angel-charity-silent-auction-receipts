# Add text normalization to auction item descriptions

The auction item descriptions in the JSON output have formatting issues that need to be cleaned up. These issues come from the source CSV data and include inconsistent spacing around punctuation.

## Problems Found

**Spaces before punctuation:**

- `"services ."` - space before period
- `"artist ,"` - space before comma
- `"cubism ."` - space before period

**Double spaces:**

- `"This is a  rare"` - double space between words
- `"vision of  Jack"` - double space between words

**Missing spaces after punctuation:**

- `"finger.Good"` - no space after period between sentences
- `"collectors.With"` - no space after period between sentences
- `"you!Lounge"` - no space after exclamation
- `"Arizona.Certificate"` - no space after period between sentences

**Spaces before semicolons:**

- `"petting ; learning"` - space before semicolon
- `"Amber Levitz ; Lindsay"` - space before semicolon

## Requirements

Add text normalization to the `Receipts.AuctionItem` module that:

1. Removes spaces before punctuation (`.`, `,`, `!`, `?`, `;`, `:`)
2. Ensures single space after sentence-ending punctuation (`.`, `!`, `?`)
3. Collapses multiple consecutive spaces into a single space
4. Applies to the `description` field during `AuctionItem.new/1`
5. Also normalizes `title` and `short_title` fields
