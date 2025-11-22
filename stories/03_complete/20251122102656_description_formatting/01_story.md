# Description Formatting

A lot of the descriptions have formatting in the CSV that's being removed when importing. For example:

```text
Enjoy 6 nights in one of the finest villas in Belize! All located on the Caribbean Sea with four bedrooms, the villas are true Central American gems. A short step out the back door will take you right into the ocean. Placencia is known for breathtaking world class snorkeling and diving as well as numerous other water sports. The fishing is some of the best in the world. A short boat ride will take you to the majestic Monkey River, where you will have firsthand encounters with the local monkey populations! INCLUDES:- 6 Nights in 4BR Belizean villa (sleeps up to 8 people- Full service concierge- $250 utilities credit- Valid for a wide range of dates throughout the yearYour villa will have queen or king beds in each room with private bath, Wifi, and TV. Most villas also have a private onsite pool. All come with linens, towels, a few rolls of paper towels and toilet paper. Soap (dish washing or laundry soap) and groceries are not included and can be purchased locally.$65 pp in country service fee applies. Book within 12 months of purchase; complete travel within 18 months of purchase. Non-refundable; fully transferrable.
```

This has line breaks and bulleted lists, but with the formatting removed it looks like one long blob of text. I wonder if we can convert the text into HTML?

Here is a good example of original formatted text:

```text
Win a a perfect trip to discover some Portuguese wine regions, while also enjoying the comfort of staying at two Portugal manor house estates. This one-week trip combines the discovery of the landscape and cultural jewels of the historic Minho and the UNESCO-protected Douro Valley with the enjoyment of high-quality wines and instructive insights into the production methods. Your accommodations are two internationally renowned wineries in the &ldquo;Solares de Portugal.&rdquo; Viana do Castelo and Lamego, Portugal

INCLUDES:
- 7 nights accommodation
- 4 nights at Quinta do Ameal, Viana do Castelo and 3 nights at Casa de Santo Ant&oacute;nio de Britiande, Lamego
- Welcome-Drink at each property

- 2 Cooking classes
- 2 Wine tastings
- Breakfast included daily
- 2 Dinners (excluding drinks)

- Valid year-round; weekday check-ins only

Travelers are responsible for all transportation, including airport transfers and transportation between cities.

NOT INCLUDED: flights, meals ; beverages not mentioned, rental car, fuel, tolls, guides, entrance fees to archeological sites, museums, and wineries outside the properties where you are staying, personal expenses, private or guided tours

Subject to availability. Not valid during Thanksgiving, Christmas ; USA holidays.
```

When we convert this to JSON, can we maintain the plain text formatting?
