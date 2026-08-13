# Notification System

## Architecture

```text
Flutter app
  |
  | Requests notification permission
  | Registers the current FCM token
  | Persists user delivery preferences
  v
Firestore
  users/{uid}
  users/{uid}/fcmTokens/{token}
  notifications/{notificationId}
  |
  | Domain events are written by the app/backend
  | - offers/{offerId}
  | - chat_rooms/{chatRoomId}/messages/{messageId}
  | - payments/{paymentId}
  v
Cloud Functions
  |
  | Maps each event into a normalized notification document
  | Delivers through enabled channels
  | - FCM push
  | - SendGrid email
  | - Twilio SMS
  v
Flutter runtime
  |
  | Shows Android foreground alerts via flutter_local_notifications
  | Opens the notification center on tap
  | Marks notifications read from the inbox or push tap
  v
Firestore read state
```

## Event Flow

1. The app creates or updates domain data such as an offer, chat message, or payment.
2. A Firestore trigger in `functions/index.js` calls the matching handler in `functions/notification_engine.js`.
3. The handler writes a normalized `notifications/{notificationId}` document with:
   - recipient
   - event type
   - channels
   - metadata
   - initial delivery state
4. `deliverNotification` reacts to that notification document and checks:
   - FCM tokens in `users/{uid}/fcmTokens`
   - `users/{uid}.notificationPreferences`
   - provider env vars for email and SMS
5. Delivery results are written back under `delivery.push`, `delivery.email`, and `delivery.sms`.
6. The Flutter app streams the same notification collection for the notification center and unread badge.

## Firestore Schema

### `users/{uid}`
- `notificationPreferences.push`: bool
- `notificationPreferences.email`: bool
- `notificationPreferences.sms`: bool
- `notificationPreferences.offers`: bool
- `notificationPreferences.messages`: bool
- `notificationPreferences.payments`: bool

### `users/{uid}/fcmTokens/{token}`
- `token`: string
- `platform`: `android | ios | web | macos | ...`
- `enabled`: bool
- `app`: `estatex`
- `createdAt`: timestamp
- `updatedAt`: timestamp
- `disabledReason`: string | null

### `notifications/{notificationId}`
- `userId`: recipient uid
- `actorId`: sender uid or `system`
- `type`: `offer_created | offer_status_update | counter_offer | chat_message | payment_success | payment_failed | ...`
- `title`: string
- `message`: string
- `metadata`: map
- `channels`: array such as `['push', 'in_app', 'email']`
- `priority`: `normal | high`
- `read`: bool
- `readAt`: timestamp | null
- `delivery.push.status`: `pending | sent | skipped | failed`
- `delivery.email.status`: `pending | sent | skipped | failed`
- `delivery.sms.status`: `pending | sent | skipped | failed`
- `createdAt`: timestamp
- `updatedAt`: timestamp

## Flutter App Pieces

### Runtime
- `lib/main.dart`
  Starts `AppNotificationService` before the app runs and shares a navigator key for push tap routing.
- `lib/notifications/notification_service.dart`
  Handles FCM permission requests, token registration, Android foreground alerts, push tap handling, unread counts, and preference updates.
- `lib/notifications/notification_models.dart`
  Defines `AppNotification` and `NotificationPreferences`.

### UI
- `lib/notifications/notification_center_screen.dart`
  Firestore-backed inbox with unread filtering, per-channel chips, and mark-as-read support.
- `lib/navigation/main_navigation.dart`
  Adds a live unread badge to the Alerts tab.
- `lib/profile/profile_screen.dart`
  Adds a notification preference card so users can opt into email and SMS delivery.

## Cloud Functions

Implemented in:
- `functions/index.js`
- `functions/notification_engine.js`

Triggers:
- `deliverNotification`
- `notifyOfferCreated`
- `notifyOfferUpdated`
- `notifyChatMessageCreated`
- `notifyPaymentUpdated`

Delivery providers:
- Push: Firebase Admin SDK and FCM
- Email: SendGrid REST API
- SMS: Twilio REST API

Email and SMS are skipped safely when provider credentials are not configured.

## Required Config

Firebase Functions env file:
- `SENDGRID_API_KEY`
- `NOTIFICATION_EMAIL_FROM`
- `TWILIO_ACCOUNT_SID`
- `TWILIO_AUTH_TOKEN`
- `TWILIO_FROM_NUMBER`

Also required for payments and agreements already used in this project:
- `RAZORPAY_KEY_ID`
- `RAZORPAY_KEY_SECRET`
- `RAZORPAY_WEBHOOK_SECRET`
- DocuSign credentials

## Deployment Checklist

1. Run `flutter pub get`.
2. Run `cd functions` then `npm install`.
3. Add the env vars from `functions/.env.example`.
4. Deploy Functions, rules, and indexes:
   `firebase deploy --only functions,firestore:rules,firestore:indexes`
5. In Firebase Console, upload APNs credentials for iOS push delivery.
6. In Xcode, enable Push Notifications and Background Modes for the Runner target.
7. On Android 13+, the app requests `POST_NOTIFICATIONS`, and foreground alerts are shown through the `estatex_alerts` local notification channel.
