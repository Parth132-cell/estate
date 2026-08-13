# Seller Property Management

This app now treats seller listings as a small lifecycle instead of a single moderation status.

## Firestore shape

Collection: `properties/{propertyId}`

Core seller fields:

- `title`: `string`
- `price`: `int`
- `city`: `string`
- `city_lower`: `string`
- `locality`: `string`
- `locality_lower`: `string`
- `bhk`: `int`
- `listingType`: `string`
- `description`: `string`
- `areaSqft`: `int?`
- `latitude`: `double?`
- `longitude`: `double?`
- `searchLocation`: `{ latitude, longitude }?`
- `imageUrls`: `string[]`
- `images`: `string[]`

Ownership:

- `createdBy`: seller uid
- `uploadedBy`: seller uid

Lifecycle:

- `verificationStatus`: `draft | pending | approved | rejected`
- `listingStatus`: `draft | active | sold | archived`
- `status`: derived UI/query status

Important timestamps:

- `createdAt`
- `updatedAt`
- `lastSellerActionAt`
- `draftSavedAt`
- `submittedAt`
- `resubmittedAt`
- `moderatedAt`
- `soldAt`
- `archivedAt`

Audit-style metadata:

- `resubmissionCount`
- `rejectionReason`
- `moderatedBy`
- `soldBy`
- `archivedBy`

## Lifecycle rules

- Draft save: `verificationStatus=draft`, `listingStatus=draft`, `status=draft`
- Submit for review: `verificationStatus=pending`, `listingStatus=active`, `status=pending`
- Approved live listing: `verificationStatus=approved`, `listingStatus=active`, `status=approved`
- Rejected listing: `verificationStatus=rejected`, `listingStatus=active`, `status=rejected`
- Mark sold: keep `verificationStatus=approved`, set `listingStatus=sold`, `status=sold`
- Archive: keep `verificationStatus`, set `listingStatus=archived`, `status=archived`

## Seller actions

- `saveDraft`: create or update incomplete listings safely
- `updateListing`: edits an existing listing and returns it to review when needed
- `resubmitRejectedProperty`: clears the rejection reason and sends the listing back to review
- `markAsSold`: closes an approved active listing
- `archiveListing`: removes a listing from active management without deleting it
- `restoreListing`: reactivates archived listings based on their verification state
