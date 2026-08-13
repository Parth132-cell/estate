# Razorpay Payment System

## Backend endpoints

Base URL:
- `https://<region>-<project>.cloudfunctions.net/paymentApi`

Endpoints:
- `POST /payments/razorpay/orders`
- `POST /payments/razorpay/verify`
- `POST /payments/razorpay/failure`
- `POST /payments/razorpay/webhook`

Auth:
- Mobile calls send Firebase ID token in `Authorization: Bearer <token>`.
- Webhooks do not use Firebase auth; they are verified with `X-Razorpay-Signature`.

## Firestore structure

### `payments/{paymentId}`
- `provider`: `razorpay`
- `escrowId`: string
- `dealId`: string
- `propertyId`: string
- `buyerId`: string
- `brokerId`: string
- `amount`: int
- `currency`: string
- `status`: `order_created | authorized | captured | failed | refunded`
- `paymentStatus`: `pending | success | failed`
- `verificationStatus`: `pending | verified | failed`
- `description`: string
- `receipt`: string
- `initiatedBy`: string
- `failureReason`: string | null
- `webhookLastEvent`: string | null
- `gateway.orderId`: string
- `gateway.paymentId`: string | null
- `gateway.status`: string | null
- `gateway.signatureVerified`: bool
- `gateway.webhookSignatureVerified`: bool
- `gateway.signature`: string | null
- `gateway.payment`: sanitized Razorpay payment payload
- `createdAt`: timestamp
- `updatedAt`: timestamp
- `verifiedAt`: timestamp | null
- `authorizedAt`: timestamp | null
- `capturedAt`: timestamp | null
- `failedAt`: timestamp | null

### `payments/{paymentId}/events/{eventId}`
- `source`: `backend | client | webhook`
- `type`: string
- `gatewayOrderId`: string | null
- `gatewayPaymentId`: string | null
- `paymentStatus`: `pending | success | failed`
- `payload`: map
- `createdAt`: timestamp

### `payment_webhook_events/{eventId}`
- `eventId`: string
- `eventType`: string
- `orderId`: string | null
- `gatewayPaymentId`: string | null
- `receivedAt`: timestamp

## Escrow linkage

The backend mirrors the secure payment identifiers onto `escrow/{escrowId}`:
- `paymentRecordId`
- `paymentOrderId`
- `transactionId`
- `paymentStatus`
- `provider`

This lets the app render escrow state without storing raw gateway secrets on device.

## Required secrets

Backend environment:
- `RAZORPAY_KEY_ID`
- `RAZORPAY_KEY_SECRET`
- `RAZORPAY_WEBHOOK_SECRET`
- `PAYMENT_APP_NAME`

Flutter runtime:
- `--dart-define=PAYMENTS_API_BASE_URL=https://<region>-<project>.cloudfunctions.net/paymentApi`

## Flow

1. Buyer creates escrow in Firestore.
2. Flutter calls backend to create a Razorpay order.
3. Backend writes `payments/{paymentId}` and returns `orderId + keyId`.
4. Flutter opens Razorpay checkout with that order.
5. On success, Flutter sends `orderId + paymentId + signature` to backend.
6. Backend verifies the signature and fetches the payment from Razorpay.
7. Webhooks act as the source of truth for later status reconciliation and idempotent updates.
