# Extract expiration dates and special notes from descriptions

The auction items have descriptions that come from the CSV file in the field "1500 CHARACTER DESCRIPTION (OPTIONAL)". These descriptions have text in them that describe the item. But many of these descriptions include text that includes information about expiration. And, many have special notes that are really separate from the item description. We have fileds for notes and expiration_notice in our auction item Ecto model. I need to use AI to read through the descriptions and for the ones that have these addtional pieces of content, extract that content out into the appropriate field, leaving the description just a description about the auction item. I'd like to use AI to do this.

## Options

It seems like there are two options for doing this. Having Claude Code look over the file and make the extractions at once. Or, we could connect to the Anthropic API, and when creating the JSON file, for each item, we could make an API call to process the descriptions. I need help figuring out what is the best and most reliable approach. The auction items list is going to change and be added to several times, so this needs to be a repeatable and reliable task. Let's have a discussion about the pros and cons of the different approaches and then let's add our decision to the "Approach Decision" section below.

## Approach Decision

**Decision: API Integration (Approach 2)**

We will integrate the Anthropic API into the existing CSV-to-JSON processing pipeline. When creating JSON files, the system will make an API call for each item to extract notes and expiration dates from descriptions.

**Rationale:**

The API integration approach was chosen because this needs to be a repeatable and reliable task. The auction items list will change and be added to several times.

- **Repeatable**: Fully automated - just run the processing task and everything gets handled
- **Reliable**: Consistent extraction logic across all items
- **Scalable**: Easy to handle incremental updates and new items
- **Maintainable**: Version controlled and testable code
- **Efficient**: Can add smart caching to avoid re-processing unchanged items

The manual approach (having Claude Code process files directly) would require human intervention each time new items are added, making it unsuitable for the repeatable nature of this requirement.

**Implementation Details:**

- Use config/runtime.exs for API key management (standard Elixir approach)
- API key stored in .env file (not committed to git)
- Use Claude Haiku for cost-effectiveness
- Add optional flag to control when API processing occurs
- Cache results to avoid unnecessary reprocessing
- Log extractions for audit purposes
