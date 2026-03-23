# Firestore Schema: CRM Lead Management

## Collection: `leads`

Each document stores one lead owned by a broker.

### Document fields

| Field | Type | Required | Description |
|---|---|---|---|
| `brokerId` | `string` | yes | Broker user id that owns the lead. |
| `buyerId` | `string` | yes | User id that created or is assigned to the lead. |
| `name` | `string` | yes | Lead full name. |
| `phone` | `string` | yes | Lead contact number. |
| `status` | `string` | yes | Lead status enum: `new`, `contacted`, `closed`. |
| `priority` | `string` | yes | Priority enum: `low`, `medium`, `high`. |
| `followUpDate` | `timestamp \| null` | no | Next follow-up date used for reminders. |
| `lastContacted` | `timestamp \| null` | no | Last time lead status was moved to contacted. |
| `notes` | `array<object>` | yes | Timeline notes on the lead. |
| `createdAt` | `timestamp` | yes | Creation timestamp. |
| `updatedAt` | `timestamp` | yes | Last update timestamp. |

### Notes item format

```json
{
  "text": "Lead asked for weekend call",
  "createdAt": "Timestamp",
  "createdBy": "uid"
}
```

## Query/index plan

Composite indexes are expected for:

1. `brokerId + createdAt(desc)`
2. `brokerId + status + createdAt(desc)`
3. `brokerId + priority + createdAt(desc)`

These support lead list ordering, status filters, and priority filters.

## Reminder strategy

Reminder notifications are generated in app logic by querying broker leads and flagging records where:

- `followUpDate <= today`
- `status != closed`

## Analytics inputs

Dashboard KPI cards can be computed from this schema:

- Total leads
- Status split (`new`, `contacted`, `closed`)
- Priority split (`high`, `medium`, `low`)
- Reminders due
- Leads with notes
- Contact/close rate
