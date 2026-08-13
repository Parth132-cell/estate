# Search System

## What Changed

- City and locality are now first-class search fields.
- Search supports `newest`, `price low to high`, and `price high to low`.
- Explore has both list and map views.
- Users can save a search and receive alerts when a newly approved property matches it.

## Firestore Query Strategy

### Property fields used for search

Store these on each property document:

- `verificationStatus`
- `city`
- `city_lower`
- `locality`
- `locality_lower`
- `bhk`
- `price`
- `createdAt`
- `latitude` and `longitude` when available

### Query optimization

The search repository always starts with:

```text
properties
  where verificationStatus == approved
```

Then it layers on exact-match filters:

- `city_lower == selectedCity`
- `locality_lower == selectedLocality`
- `bhk == selectedBhk`

And optional range filters:

- `price >= minPrice`
- `price <= maxPrice`

Sorts:

- `newest` -> `orderBy(createdAt desc)`
- `priceLowToHigh` -> `orderBy(price asc, createdAt desc)`
- `priceHighToLow` -> `orderBy(price desc, createdAt desc)`

### Why exact normalized fields

Using `city_lower` and `locality_lower` avoids case-sensitive misses and keeps the Firestore queries index-friendly.

### Map search

Map view reads the same filtered Firestore result set and plots listings using:

- real `latitude` and `longitude` when stored
- approximate city-based fallback coordinates for older listings

That keeps Firestore queries simple while still delivering a map-driven browsing experience.

## Saved Search Alerts

Saved searches live in:

```text
saved_searches/{savedSearchId}
```

Fields:

- `userId`
- `label`
- `city`
- `cityLower`
- `locality`
- `localityLower`
- `bhk`
- `minPrice`
- `maxPrice`
- `sort`
- `alertEnabled`
- `createdAt`
- `updatedAt`

Cloud Functions watch newly approved properties and compare them against matching saved searches. For each match, the backend writes a notification document, which then fans out to:

- push
- in-app inbox
- email

## Flutter UI

Main screen:

- `lib/explore/explore_search_screen.dart`

Supporting files:

- `lib/explore/property_listing_repository.dart`
- `lib/explore/explore_map_view.dart`
- `lib/explore/saved_search_service.dart`

User-facing features:

- city search
- locality search
- BHK filter
- price range filter
- sort selector
- list/map toggle
- saved search chips
- save alert button

## Recommended Deployment Steps

1. Run `flutter pub get`.
2. Deploy Firestore indexes and rules.
3. Deploy Cloud Functions for saved-search notifications.
4. Backfill `locality_lower` for older property documents if needed.
5. Backfill `latitude` and `longitude` for more accurate pins over time.
