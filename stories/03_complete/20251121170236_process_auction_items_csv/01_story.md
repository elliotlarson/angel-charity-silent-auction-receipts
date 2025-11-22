# Process Auction Items CSV

We have a CSV file with a number of auction items. This is in our app's `db` directory. We need a mix task that will ask us to pick the file we would like to process from the list of available files in `db/auction_items/csv`. When we select the file, we will need to take the file remove empty lines. Remove lines that are zeroed out... it looks like the file comes in with placeholders for auction items. We want to remove these place holders and only focus on auction item lines with real data. Then we want to extract a number of relevant fields out and save the file as a json file with the same name, but in the `db/auction_items/json` directory. There is a header line (not the first line of the document) that describes the columns. We want to extract the headers for the values we care about and change them to be lower case and snake case formatted (and trimmed). The values we care about are:

- `item_id`
- `categories`
- `short_title` (15 character description)
- `title` (100 character description)
- `description` (1500 character description)
- `fair_market_value`
