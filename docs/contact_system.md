# Contact System

## Firestore structure

### `leads/{leadId}`
- `buyerId`: string
- `brokerId`: string
- `propertyId`: string | null
- `propertyTitle`: string
- `name`: string
- `phone`: string
- `status`: `new | contacted | closed`
- `priority`: `low | medium | high`
- `message`: string
- `notes`: list
- `chatRoomId`: string
- `maskedPhoneAlias`: string
- `buyerPhoneMasked`: string
- `brokerPhoneMasked`: string
- `callbackRequested`: bool
- `callbackStatus`: `not_requested | pending | completed | declined`
- `unreadBuyerCount`: int
- `unreadBrokerCount`: int
- `lastMessageText`: string
- `lastMessageAt`: timestamp | null
- `lastMessageBy`: string | null
- `contactSource`: string
- `contactClicks`: int
- `lastIntentAt`: timestamp | null
- `createdAt`: timestamp
- `updatedAt`: timestamp

### `chat_rooms/{chatRoomId}`
- `leadId`: string
- `buyerId`: string
- `brokerId`: string
- `participantIds`: string[]
- `propertyId`: string | null
- `propertyTitle`: string
- `buyerName`: string
- `brokerName`: string
- `maskedPhoneAlias`: string
- `buyerPhoneMasked`: string
- `brokerPhoneMasked`: string
- `callbackRequested`: bool
- `callbackStatus`: string
- `lastMessageText`: string
- `lastMessageAt`: timestamp | null
- `lastMessageBy`: string | null
- `unreadBuyerCount`: int
- `unreadBrokerCount`: int
- `createdAt`: timestamp
- `updatedAt`: timestamp

### `chat_rooms/{chatRoomId}/messages/{messageId}`
- `chatRoomId`: string
- `leadId`: string
- `senderId`: string
- `recipientId`: string
- `senderRole`: `buyer | broker`
- `messageType`: `text`
- `text`: string
- `createdAt`: timestamp

### `callback_requests/{requestId}`
- `leadId`: string
- `chatRoomId`: string
- `brokerId`: string
- `buyerId`: string
- `propertyId`: string | null
- `propertyTitle`: string
- `requestedBy`: string
- `requestedFor`: string
- `maskedPhoneAlias`: string
- `note`: string
- `status`: `pending | completed | declined`
- `createdAt`: timestamp
- `updatedAt`: timestamp

## Backend flow

1. Buyer taps Contact.
2. App creates or reuses a deterministic lead and chat room.
3. A masked alias is generated and stored on both the lead and chat room.
4. Messages are written to the room subcollection and denormalized onto the lead/chat room.
5. Callback requests are written to `callback_requests` and mirrored onto the lead/chat room.
6. Notifications are added to `notifications` for the other participant.

## Masked number strategy

- The app never exposes raw buyer or broker phone numbers inside the contact UI.
- The contact UI shows masked phone values plus a stable alias like `EST-123ABC`.
- This alias is the handoff point for a future telephony relay provider if PSTN masking is added later.
