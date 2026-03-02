# EstateX SRS Traceability Matrix (Current Codebase Gap Check)

This matrix maps the provided SRS expectations to the current Flutter codebase status.

Status legend:
- ✅ Implemented
- 🟡 Partial / basic
- ❌ Missing

## A) Functional Traceability

| SRS Area | Requirement | Current Evidence in Code | Status | What is Left |
|---|---|---|---|---|
| Auth & onboarding | Phone OTP login + session gate | `AuthGate` on `authStateChanges`, OTP send/verify in `AuthController` | 🟡 | Strengthen production auth settings, remove testing-only verification bypass in production builds |
| User bootstrap | Ensure user profile doc exists | `UserInitService.ensureUserDocument()` creates user doc if absent | 🟡 | Enforce role/profile schema + server-side constraints and retries |
| Verified listing upload | Add property with images | `PropertyService.submitProperty()` uploads to Firebase Storage and stores URLs | 🟡 | Add document/KYC upload, geo-verification, moderation metadata |
| Listing verification | Admin approve/reject listing | `AdminScreen` + `AdminPropertyTile` update `verificationStatus` | 🟡 | Workflow states, rejection reasons, audit logs, SLA timers |
| Property exploration | Browse + filters + details | `HomeScreen`, `ExploreScreen`, `PropertyDetailsScreen` | 🟡 | Rich filters (price ranges, map radius, amenities), sort relevance |
| Save/favorites | Save and list favorites | `saved_service.dart`, `saved_properties.dart` | ✅ | Add pagination + optimistic updates + telemetry |
| Compare | Compare multiple properties | `CompareScreen` + `ComparisonService` | 🟡 | Handle >10 IDs robustly, normalized comparison metrics |
| Broker CRM | Lead list and updates | `LeadService`, `BrokerLeadsScreen` (status/priority/follow-up fields) | 🟡 | Pipeline board, reminders, conversion analytics, SLA reporting |
| Co-broker collaboration | Multi-broker participation | No explicit co-broker model/split workflow found | ❌ | Data model for co-broker roles, invitation/accept flow, commission split logic |
| Negotiation | Offer/counter flow | `DealServices.createOffer/counterOffer/updateDealStatus` | 🟡 | Negotiation history timeline, constraints, assistant suggestions |
| Escrow | Hold/release/refund states | `EscrowService` (Firestore status transitions) | 🟡 | Real gateway integration, transaction proofs, webhook reconciliation |
| Digital agreements | Agreement create/accept | `AgreementService` + `AgreementScreen` | 🟡 | Real document generation + eSign provider integration |
| Agreement document | Legally binding PDF | `AgreementPdfStub` is placeholder | ❌ | Dynamic PDF templates, signatures, storage/versioning |
| Activity feed | User activity list | `ActivityScreen` stream from `activities` | 🟡 | Standardized event schema, filtering, read-state/notifications |
| Admin operations | Pending listing review | `AdminScreen` pulls pending properties | 🟡 | User risk actions, dispute case queue, fraud flags |
| Reviews & ratings | Capture/display ratings | `reviews/*` screens/services/models | 🟡 | Moderation, anti-abuse checks, weighted scoring |
| Live video tours | Real-time tours | No RTC/video integration found | ❌ | RTC SDK integration, schedule/join/recording, quality telemetry |
| AI recommendations | Personalized suggestions | No AI/recommendation service found | ❌ | Ranking pipeline, embeddings/features, explainability UI |
| AR preview | AR visualization | No AR SDK/screens found | ❌ | AR SDK integration + property space calibration workflow |
| Secure documents | Property docs upload/validation | Images only; no docs pipeline found | ❌ | File-type validation, OCR/extraction, secure access controls |

## B) External Interface Traceability (SRS 2.1)

| Interface in SRS | Current State | Status | What is Left |
|---|---|---|---|
| Payment gateway (Razorpay/Stripe) | No gateway package/integration in dependencies | ❌ | SDK integration, backend order creation, webhooks, signature verification |
| eSign APIs | Agreement flow exists but no eSign integration | ❌ | Integrate eSign provider + consent flow + signed doc archival |
| AI models | No model client/inference path in app code | ❌ | Define AI service contracts and call paths |
| AR visualization SDK | No AR dependency/integration detected | ❌ | Add AR SDK and end-to-end preview UX |
| Verification APIs | Not present (manual/admin-only checks) | ❌ | ID/property verification provider integration |
| Cloud storage (AWS S3) | Uses Firebase Storage currently | 🟡 | Decide architecture: keep Firebase or migrate/dual-write to S3 |

## C) Non-functional/Quality Gaps (from current code posture)

| NFR Theme | Observation | Gap |
|---|---|---|
| Reliability | Several services still use `currentUser!` assumptions in places | Null-safe auth guards and centralized auth abstraction incomplete |
| Security | Client-heavy write paths; no visible server-rule traceability doc in repo | Need strict Firestore rules + backend trust boundaries |
| Scalability | Basic stream queries without pagination in many lists | Add paging/cursors and index strategy |
| Observability | Minimal structured logging and no analytics events taxonomy | Add telemetry schema + error monitoring |
| Testability | No visible automated coverage tied to SRS items | Add unit/widget/integration tests per critical flow |

## D) Suggested Implementation Phases

1. **Phase 1 (transaction core hardening)**
   - Payment gateway + escrow reconciliation
   - Agreement PDF generation + eSign
   - Firestore rules hardening + auth guard cleanup

2. **Phase 2 (broker operations maturity)**
   - CRM pipeline dashboard, reminders, analytics
   - Co-broker workflow + commission split
   - Dispute management in admin

3. **Phase 3 (experience differentiation)**
   - Live tour RTC module
   - AI recommendations + negotiation assistant
   - AR preview integration

## E) Immediate Backlog (Actionable Tickets)

- [ ] Add payment provider integration layer and webhook verification backend.
- [ ] Replace `AgreementPdfStub` with generated PDF + signature lifecycle.
- [ ] Add co-broker data model (`coBrokerId`, `splitPercent`, acceptance states).
- [ ] Add live tour entities (`tourSession`, host/participants, schedule, state machine).
- [ ] Add recommendation API contract (`/recommendations?userId=`) and UI cards.
- [ ] Add AR preview route and fallback UX for unsupported devices.
- [ ] Add fraud/dispute admin collections and queue UI.
- [ ] Add SRS-linked tests and a release checklist matrix.

