# Agreement + eSign System

## Backend Flow

```text
Flutter App
  |
  | 1. Create agreement draft in Firestore
  v
Firestore: agreements/{agreementId}
  |
  | 2. Request backend PDF render
  v
Firebase Functions / Node.js
  |
  | 3. Build PDF dynamically from agreement data
  | 4. Return PDF bytes to app
  v
Flutter uploads draft PDF to Storage
  |
  | 5. Request DocuSign envelope
  v
Firebase Functions / DocuSign API
  |
  | 6. Create envelope with buyer + seller recipients
  | 7. Persist envelopeId / signatureRequestId / signer states
  v
Firestore: agreements/{agreementId}
  |
  | 8. Signer opens embedded signing session
  v
DocuSign Recipient View
  |
  | 9. DocuSign Connect webhook notifies backend
  v
Firebase Functions
  |
  | 10. Sync signer statuses and envelope status
  | 11. When completed, download combined signed PDF
  | 12. Store signed PDF in Firebase Storage
  v
Firestore + Storage
```

## Firestore Shape

### `agreements/{agreementId}`
- `dealId`: string
- `buyerId`: string
- `sellerId`: string
- `status`: `draft | accepted | rejected`
- `documentBody`: string
- `esignProvider`: `docusign`
- `esignStatus`: `not_sent | pending_buyer | pending_seller | completed | declined | voided`
- `envelopeId`: string | null
- `envelopeStatus`: string | null
- `signatureRequestId`: string | null
- `pdfUrl`: string | null
- `signedPdfUrl`: string | null
- `signedPdfPath`: string | null
- `signers.buyer.userId`: string
- `signers.buyer.name`: string | null
- `signers.buyer.email`: string | null
- `signers.buyer.status`: string
- `signers.buyer.signedAt`: string | null
- `signers.seller.userId`: string
- `signers.seller.name`: string | null
- `signers.seller.email`: string | null
- `signers.seller.status`: string
- `signers.seller.signedAt`: string | null
- `esignSyncedAt`: timestamp | null
- `esignLastSyncSource`: string | null
- `createdAt`: timestamp
- `updatedAt`: timestamp

### `agreement_webhook_events/{eventId}`
- raw DocuSign Connect event payload
- stored for debugging and replay analysis

## API Integration Steps

Provider used here: DocuSign eSignature

1. Create a DocuSign app and integration key.
2. Decide auth mode:
   - For service-style backend sending, JWT is practical.
   - Official DocuSign guidance notes JWT is used for service integrations, while Authorization Code is preferred when a browser redirect is practical.
3. Grant consent for `signature` and `impersonation` scopes.
4. Configure environment variables:
   - `DOCUSIGN_INTEGRATION_KEY`
   - `DOCUSIGN_USER_ID`
   - `DOCUSIGN_ACCOUNT_ID`
   - `DOCUSIGN_PRIVATE_KEY`
   - `DOCUSIGN_AUTH_SERVER`
   - `DOCUSIGN_RETURN_URL`
   - optional Connect settings:
     - `DOCUSIGN_CONNECT_URL`
     - `DOCUSIGN_CONNECT_BASIC_USER`
     - `DOCUSIGN_CONNECT_BASIC_PASS`
     - `DOCUSIGN_CONNECT_HMAC_SECRET`
5. Deploy Functions and set Flutter runtime:
   - `--dart-define=AGREEMENTS_API_BASE_URL=https://<region>-<project>.cloudfunctions.net/paymentApi`
6. Make sure buyer and seller user docs have valid email addresses.
7. Configure DocuSign Connect to send JSON notifications to the webhook route if you want account-level webhook setup in addition to the per-envelope callback.
   - The current backend webhook parser expects JSON payloads, not XML.

## Implemented Backend Routes

- `POST /agreements/render`
- `POST /agreements/signatures/request`
- `POST /agreements/:agreementId/signing-session`
- `POST /agreements/:agreementId/sync-signature-status`
- `POST /agreements/docusign/connect`
