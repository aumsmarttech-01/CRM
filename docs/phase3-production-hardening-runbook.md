# Phase 3 Production Hardening Runbook

This runbook continues AUM CRM from functional MVP into production readiness.

## Phase 3 Scope

1. Audit logging verification
2. Security middleware deployment verification
3. WhatsApp dispatch tests
4. Client portal object-level scoping
5. End-to-end acceptance workflow validation
6. Production backup strategy

## 1. Audit Logging Verification

### Goal

Confirm every sensitive create/update/delete action writes to `audit_logs`.

### Required audit fields

- actor_type
- actor_user_id
- actor_email
- action
- table_name
- record_id
- before_data
- after_data
- ip_address
- user_agent
- request_id
- status_code
- created_at

### Verification actions

Perform each action from the UI or API, then confirm a row appears in `audit_logs`:

| Module | Action | Expected audit action |
| --- | --- | --- |
| Clients | Create client | CLIENT_CREATED |
| Projects | Update project status | PROJECT_UPDATED |
| Work Orders | Assign technician | WORK_ORDER_ASSIGNED |
| Attendance | Create attendance event | ATTENDANCE_EVENT_CREATED |
| Completion Proofs | Approve proof | COMPLETION_PROOF_APPROVED |
| Invoices | Create invoice | INVOICE_CREATED |
| Payments | Record payment | PAYMENT_CREATED |
| Compliance | Approve compliance | COMPLIANCE_APPROVED |
| Inventory | Adjust stock / issue material | STOCK_MOVEMENT_CREATED |
| Payroll | Approve payroll run | PAYROLL_RUN_APPROVED |
| Settings | Update setting | SETTING_UPDATED |
| Users | Change role/status | USER_UPDATED |

### SQL verification

```sql
select
  actor_type,
  actor_email,
  action,
  table_name,
  record_id,
  status_code,
  created_at
from audit_logs
order by created_at desc
limit 50;
```

### Acceptance criteria

- Every sensitive mutation creates one audit row.
- Secrets/passwords/tokens are redacted.
- Audit failure does not break normal business action.
- EXECUTIVE/ADMIN can view audit logs.
- Non-admin roles cannot view audit logs.

## 2. Security Middleware Deployment Verification

### Required controls

- `app.disable("x-powered-by")`
- JSON body limit
- URL encoded body limit
- General API rate limiting
- Auth endpoint stricter rate limiting
- CSP header
- HSTS header
- X-Frame-Options header
- X-Content-Type-Options header
- Referrer-Policy header
- Permissions-Policy header
- Same-origin mutation guard
- Strong production `SESSION_SECRET`

### Smoke tests

Run against the deployed API:

```bash
curl -I https://YOUR-REPLIT-DOMAIN/api/healthz
```

Confirm headers include:

```text
content-security-policy
strict-transport-security
x-frame-options
x-content-type-options
referrer-policy
permissions-policy
```

### Auth rate limit test

Attempt repeated failed login requests. Expected result:

```text
429 Too Many Requests
```

### Acceptance criteria

- Headers exist on API responses.
- Failed login brute force is rate-limited.
- Large request body is rejected.
- Production refuses weak default SESSION_SECRET.

## 3. WhatsApp Dispatch Tests

### Goal

Verify the notification outbox handles WhatsApp correctly.

### Required test scenarios

1. Delivery success
   - Given WHATSAPP_TOKEN and WHATSAPP_PHONE_NUMBER_ID are configured
   - When a pending WhatsApp notification is dispatched
   - Then status becomes SENT

2. Temporary failure and retry
   - Given WhatsApp provider returns 500/timeout
   - When dispatch runs
   - Then attempts increments
   - And status remains PENDING
   - And next_attempt_at is set

3. Permanent failure
   - Given attempts reaches max retry threshold
   - When dispatch fails again
   - Then status becomes FAILED
   - And last_error is populated

4. Missing configuration
   - Given WhatsApp credentials are absent
   - When a WhatsApp notification is queued/dispatched
   - Then status becomes SKIPPED
   - Or the notification service avoids enqueueing WhatsApp and records SYSTEM/email only, depending current implementation

### Test file target

Add tests near the current automation/notification test suite:

```text
artifacts/api-server/src/lib/__tests__/notify.whatsapp.test.ts
```

or the existing notification test folder if one already exists.

### Acceptance criteria

- All four scenarios are covered.
- Tests mock external network calls.
- No real WhatsApp API call is made in tests.
- `pnpm run test` or current test command passes.

## 4. Client Portal Object-Level Scoping

### Goal

Client users must only access records belonging to their `client_id`.

### Scope every client portal endpoint

Client users may access only their own:

- projects
- service tickets
- invoices
- payments/payment status
- AMC contracts
- AMC visits
- documents
- feedback
- compliance records meant for the client
- review request links where appropriate

### Enforcement pattern

Every client portal query must include:

```text
where client_id = req.client.clientId
```

Never trust a client-provided `clientId` request body or query parameter.

### Dangerous patterns to remove

```ts
const clientId = req.body.clientId;
const clientId = req.query.clientId;
```

Replace with:

```ts
const clientId = req.client.clientId;
```

### Tests

Create two client users for different clients:

- Client A user
- Client B user

Verify:

- Client A cannot fetch Client B tickets.
- Client A cannot fetch Client B invoices.
- Client A cannot submit feedback against Client B project.
- Client A cannot download Client B documents.

### Acceptance criteria

- Cross-client access returns 403 or 404.
- No endpoint leaks another client's data.
- Client portal dashboard is scoped by authenticated client ID.

## 5. End-to-End Acceptance Workflow

### Goal

Prove the CRM/ERP works as one connected operating system.

### Test workflow

1. Create/import client.
2. Create lead.
3. Create quotation with quotation items.
4. Accept quotation and create project.
5. Create site.
6. Create work order.
7. Assign technician.
8. Record attendance event.
9. Generate/approve timesheet.
10. Create labor project cost.
11. Issue material or create material project cost.
12. Submit completion proof.
13. Approve completion proof.
14. Confirm compliance records are approved or not required.
15. Close work order.
16. Create invoice.
17. Record payment.
18. Confirm invoice becomes PAID.
19. Confirm review request is created.
20. Confirm project profitability endpoint returns:
    - revenue
    - collected
    - outstanding
    - material cost
    - labor cost
    - total cost
    - gross profit
    - margin percent
21. Confirm audit logs exist for all critical mutations.

### Acceptance criteria

The system is production-MVP ready only if this entire workflow passes without manual database edits.

## 6. Production Backup Strategy

### Database backup

Supabase should have point-in-time recovery where available. In addition, create manual SQL dumps before major migrations/imports.

### Pre-deployment backup command

Run from a secure shell where DATABASE_URL is already configured as an environment variable:

```bash
mkdir -p backups
pg_dump "$DATABASE_URL" > "backups/aum_crm_pre_deploy_$(date +%Y%m%d_%H%M%S).sql"
```

### Post-import backup command

```bash
pg_dump "$DATABASE_URL" > "backups/aum_crm_post_import_$(date +%Y%m%d_%H%M%S).sql"
```

### Backup rules

- Never commit backup files to GitHub.
- Never paste DATABASE_URL into chat.
- Store backups in secure cloud storage.
- Keep at least:
  - one pre-deployment backup
  - one post-deployment backup
  - one post-import backup

### Restore drill

At least once before production handover:

1. Create a temporary database.
2. Restore latest backup.
3. Run app smoke test.
4. Confirm login, dashboard, clients, projects, invoices load.

## Replit Execution Prompt

Use this prompt in Replit AI:

```text
Continue AUM CRM Phase 3 production hardening.

Implement and verify:

1. Audit logging verification
- Confirm audit_logs table exists.
- Confirm mutation audit middleware is active.
- Confirm create/update/delete actions write audit rows.
- Add tests or a verification script if missing.

2. Security middleware deployment
- Confirm CSP, HSTS, X-Frame-Options, nosniff, Referrer-Policy, Permissions-Policy.
- Confirm general rate limiting and auth rate limiting.
- Confirm production SESSION_SECRET cannot use weak fallback.

3. WhatsApp dispatch tests
- Add tests for SENT, retry/PENDING, FAILED, and SKIPPED.
- Mock external WhatsApp API calls.

4. Client portal object-level scoping
- Ensure every client portal endpoint scopes by authenticated clientId.
- Do not trust clientId from body/query.
- Add cross-client access tests.

5. End-to-end acceptance validation
- Run Lead -> Quotation -> Project -> Work Order -> Attendance -> Timesheet -> Cost -> Proof -> Invoice -> Payment -> Review Request -> Profitability.
- Record pass/fail and blockers.

6. Production backup strategy
- Add backup runbook and pre-deployment backup command.
- Do not commit backups or secrets.

Run:
- pnpm run typecheck
- pnpm run build
- current test command

Return:
- files changed
- tests added
- commands run
- pass/fail results
- blockers
```

## Final Go/No-Go Checklist

Go-live allowed only when:

- Build passes.
- Typecheck passes.
- Database migration/push is applied.
- Audit logs verified.
- Security headers verified.
- Auth rate limiting verified.
- Client portal scoping verified.
- WhatsApp tests pass.
- Legacy data imported.
- Payroll seeded.
- End-to-end workflow passes.
- Backup created and restore drill documented.
