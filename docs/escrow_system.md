# Production Escrow System

## Architecture Diagram

```text
Buyer App
  |
  | 1. Request escrow creation
  v
Backend API (Firebase Functions / Node.js)
  |
  | 2. Validate caller, deal, property, amount, participants
  v
Firestore
  - escrows/{escrowId}
  - escrows/{escrowId}/audit_logs/{logId}
  - payments/{paymentId}
  - payment_webhook_events/{eventId}
  |
  | 3. Create payment order with gateway
  v
Razorpay
  |
  | 4. Checkout success/failure + webhook
  v
Backend API
  |
  | 5. Verify signature and payment capture
  | 6. Transition escrow: pending -> locked
  | 7. On completion: locked -> released
  | 8. On cancel/dispute: pending|locked -> refunded
  v
Firestore audit log
  |
  | 9. Clients read only
  v
Buyer / Broker / Admin dashboards
```

## State Model

Escrow states:
- `pending`: escrow shell exists, but funds are not yet fully locked
- `locked`: payment captured and held until deal completion
- `released`: funds released after completion checks pass
- `refunded`: funds returned after approved cancellation/dispute

Allowed transitions:
- `pending -> locked`
- `pending -> refunded`
- `locked -> released`
- `locked -> refunded`

Blocked transitions:
- no direct `pending -> released`
- no direct `released -> refunded`
- no transitions out of terminal states `released` or `refunded`

## Server-Side Validation Rules

At creation:
- authenticated buyer only
- backend validates `dealId`, `propertyId`, `buyerId`, `brokerId`
- amount must be a positive integer and should eventually be derived from accepted deal data, not trusted from client input

Before `pending -> locked`:
- payment signature verified server-side
- gateway payment ID, order ID, and internal payment record ID must exist
- payment capture or authorization must be confirmed by backend

Before `locked -> released`:
- deal completion flag must be true
- payment must be captured
- buyer and broker completion confirmations must both be true
- optional admin approval can be required for high-value or flagged deals

Before `pending|locked -> refunded`:
- refund approval must be true
- refund reason must be recorded
- refund reference should be stored after gateway refund completes

## Firestore Schema

### `escrows/{escrowId}`
- `dealId`: string
- `propertyId`: string
- `buyerId`: string
- `brokerId`: string
- `amount`: int
- `currency`: string
- `state`: `pending | locked | released | refunded`
- `paymentStatus`: `not_started | pending | captured | refunded`
- `paymentRecordId`: string | null
- `orderId`: string | null
- `gatewayPaymentId`: string | null
- `releaseStatus`: `not_requested | released`
- `refundStatus`: `not_requested | refunded`
- `completion.dealCompleted`: bool
- `completion.buyerConfirmed`: bool
- `completion.brokerConfirmed`: bool
- `completion.adminApproved`: bool
- `completion.completedAt`: timestamp | null
- `refund.reason`: string | null
- `refund.refundReference`: string | null
- `refund.approvedBy`: string | null
- `refund.approvedAt`: timestamp | null
- `lockedAt`: timestamp | null
- `releasedAt`: timestamp | null
- `refundedAt`: timestamp | null
- `lastActionBy`: string | null
- `lastActionRole`: string | null
- `createdAt`: timestamp
- `updatedAt`: timestamp

### `escrows/{escrowId}/audit_logs/{logId}`
- `action`: string
- `actorId`: string | null
- `actorRole`: string | null
- `fromState`: string | null
- `toState`: string | null
- `metadata`: map
- `createdAt`: timestamp

## Backend Logic Files

Implemented in:
- `functions/escrow_engine.js`
- `functions/index.js`

Routes:
- `POST /escrows`
- `POST /escrows/:escrowId/lock`
- `POST /escrows/:escrowId/release`
- `POST /escrows/:escrowId/refund`

Role boundary:
- create: authenticated buyer
- lock: admin/system-only
- release: broker or admin
- refund: admin-only

## Operational Notes

- Clients should have read-only access to production escrow records.
- All state transitions should be backend-only.
- Webhooks should be idempotent and logged in `payment_webhook_events`.
- Release and refund should never depend on a client-only flag; they must be validated against backend-owned facts.
