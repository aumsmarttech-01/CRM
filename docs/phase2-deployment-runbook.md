# Phase 2 AUM CRM Functional Wiring Runbook

This package continues the build from security/audit hardening into operational readiness.

## Included implementation pieces

- `scripts/src/import-legacy-aum.ts` — imports normalized legacy CSV bundle.
- `scripts/src/seed-aum-payroll.ts` — seeds Bromnick, Cliff, Hamishi, Kepha Mobe, and Michael payroll structure.
- `artifacts/api-server/src/routes/project-profitability.ts` — project revenue/cost/margin endpoint.
- `artifacts/api-server/src/middleware/technicianScope.ts` — helper middleware for technician object-level scoping.

## Step 1: Copy legacy import bundle into Replit

Place these files under:

```text
data/import/legacy-aum/
```

Required files:

```text
clients_import.csv
quotations_import.csv
invoices_import.csv
invoice_items_import.csv
inventory_items_import.csv
service_categories_seed.csv
legacy_task_board_import.csv
credits_receipts_review.csv
```

## Step 2: Import legacy data

Run:

```bash
pnpm exec tsx scripts/src/import-legacy-aum.ts
```

If the project does not have `tsx`, run it with the existing TypeScript runner or add `tsx` as a dev dependency.

## Step 3: Seed payroll

Run:

```bash
pnpm exec tsx scripts/src/seed-aum-payroll.ts
```

For Michael, set approved days worked only when known:

```bash
MICHAEL_DAYS_WORKED=6 pnpm exec tsx scripts/src/seed-aum-payroll.ts
```

Rules:

- Bromnick: monthly KES 20,000, no deductions.
- Cliff: monthly KES 25,000, no deductions.
- Hamishi: monthly KES 25,000, no deductions.
- Kepha Mobe: monthly KES 25,000, no deductions.
- Michael: casual/on-call technician, KES 700 per approved day, phone +254733915018.

## Step 4: Profitability endpoint

Mount `project-profitability.ts` in `artifacts/api-server/src/routes/index.ts`:

```ts
import projectProfitabilityRouter from "./project-profitability.js";
router.use("/project-profitability", authenticate, requireCapability("project-costs"), projectProfitabilityRouter);
```

Endpoint:

```text
GET /api/project-profitability/:projectId
```

Returns:

- revenue
- collected
- outstanding
- material cost
- labor cost
- equipment cost
- subcontractor cost
- travel cost
- misc cost
- total cost
- gross profit
- gross margin percent

## Step 5: Technician record-level scoping

Use `assertTechnicianCanAccessProject` on project-detail, work-order, attendance-events, timesheets, completion proofs, and project costs routes where `role === TECHNICIAN` must be limited to assigned records.

Recommended first routes to protect:

- `GET /api/projects/:id`
- `GET /api/work-orders?projectId=...`
- `GET /api/attendance-events?projectId=...`
- `POST /api/attendance-events`
- `GET /api/timesheets?projectId=...`
- `GET /api/project-costs?projectId=...`

## Step 6: WhatsApp dispatch tests

Ask Replit to add tests around `dispatchPendingNotifications()` covering:

1. WHATSAPP configured and provider returns 200 -> notification becomes SENT.
2. WHATSAPP provider returns temporary error -> notification stays PENDING and attempts increments.
3. WHATSAPP fails after max attempts -> notification becomes FAILED.
4. WHATSAPP credentials missing -> queued WhatsApp notification becomes SKIPPED or is not enqueued depending service path.

## Step 7: Acceptance test

Run the real workflow:

1. Create/import client.
2. Create/import quotation.
3. Create project.
4. Create site.
5. Create work order.
6. Assign technician.
7. Submit attendance event.
8. Generate/approve timesheet.
9. Push labor cost to project costs.
10. Issue materials / create material cost.
11. Submit and approve completion proof.
12. Create invoice.
13. Record payment.
14. Confirm invoice is PAID.
15. Confirm review request is created.
16. Confirm profitability endpoint returns correct margin.

## Step 8: Verify build

Run:

```bash
pnpm run typecheck
pnpm run build
```

Then run Drizzle push if schema changed:

```bash
pnpm --filter @workspace/db drizzle-kit push
```

or the current project-specific Drizzle command.
