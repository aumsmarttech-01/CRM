# Phase 5 Autonomous Delivery Plan

Goal: render the remaining production platform work to both backend and frontend with minimal human-in-the-loop. Human approval is only required for secrets, database-destructive actions, production cutover, and final go/no-go.

## Operating model

Use Replit AI as the coding agent, GitHub as the version-control and review system, Supabase as the database/runtime data platform, and this issue/runbook as the project control plane.

## Human approval required only for

1. Rotating or setting secrets.
2. Running destructive migrations.
3. Production database restore.
4. Final deployment/cutover.
5. Anything involving real payments, payroll release, or client notification blasts.

Everything else should be implemented, tested, and reported automatically.

## Build order

### 1. Stabilize current Phase 4 patch

Apply the existing Phase 4 full wiring patch in Replit first.

Run:

```bash
pnpm run typecheck
pnpm run build
pnpm --filter @workspace/db drizzle-kit push
pnpm exec tsx scripts/src/seed-aum-payroll.ts
```

Acceptance:
- app boots
- DB push succeeds
- audit logs table exists
- import center route loads
- frontend compiles

### 2. Backend platform layer

Create or complete:
- tenant schema scaffold
- tenant context middleware
- tenant-aware repository helpers
- payroll calculation service
- project cost service
- workflow validation service
- client portal ownership helper
- technician assignment scoping helper
- audit snapshot helper
- production backup script
- acceptance workflow script

### 3. Frontend platform layer

Create or complete:
- Admin > Audit Logs
- Admin > Data Imports
- Reports > Project Profitability
- Executive Dashboard
- Payroll Run Review page enhancements
- Technician scoped work page
- Client portal project/invoice/document pages
- Import status/history screen
- Acceptance test dashboard/checklist

### 4. Supabase database layer

Apply non-destructive schema additions first:
- tenants
- tenant_users
- audit_logs
- import_batches
- import_rows
- attendance_sync_events or attendance_sync_queue
- project_profitability_snapshots where useful

Tenant rollout should be staged:
1. create tenant tables
2. create default AUM tenant
3. backfill tenant_id into business tables
4. make tenant_id required
5. enable RLS only after API is verified tenant-aware

### 5. Testing

Required tests/verifications:
- build/typecheck
- WhatsApp SENT/retry/FAILED/SKIPPED tests
- client portal cross-client denial
- technician cross-project denial
- audit log creation for create/update/delete
- Lead -> Quotation -> Project -> Work Order -> Attendance -> Timesheet -> Cost -> Proof -> Invoice -> Payment -> Review -> Profitability

### 6. Deployment

Deploy only after:
- backup created
- restore drill documented
- secrets rotated
- typecheck passes
- build passes
- DB migration/push succeeds
- acceptance workflow passes
- client portal scoping passes
- technician scoping passes
- audit log verification passes

## Replit master prompt

Paste this into Replit AI:

```text
You are the autonomous implementation agent for AUM CRM Phase 5.

Use all current project files and previous Phase 4 patch outputs.

Goal:
Render the production platform layer to both backend and frontend with minimal human-in-the-loop.

Do not ask for confirmation except for:
- secrets
- destructive database changes
- production cutover
- real payroll/payment/client-message actions

Implement in this order:

1. Stabilize Phase 4
- Apply any missing Phase 4 files.
- Run pnpm run typecheck.
- Run pnpm run build.
- Run the current Drizzle push command.
- Fix compile errors before moving on.

2. Backend
- Add tenant scaffold: tenants and tenant_users.
- Add tenant context middleware but keep single-tenant default AUM tenant for now.
- Add tenant-aware helper functions without breaking existing routes.
- Add payroll calculation service using attendance, payroll runs, advances, leave, monthly salaries, and Michael's daily rate.
- Add project cost engine using project_costs, material requests, payroll entries, invoices, and payments.
- Add workflow validation service for work-order/project closure.
- Add client portal object-level ownership helper.
- Add technician assignment scoping helper.
- Extend audit logging with before/after snapshots where safe.
- Add production backup script and acceptance workflow script.

3. Frontend
- Add/complete Admin Audit Logs page.
- Add/complete Admin Data Imports page.
- Add/complete Project Profitability report page.
- Add/complete Executive Dashboard page with charts/cards.
- Add payroll review details showing salary, daily-rate workers, advances, leave, gross, deductions, net.
- Add technician scoped work view.
- Add client portal views for own projects, invoices, tickets, AMC, and documents only.

4. Supabase/Drizzle
- Add non-destructive schema changes only.
- Create default AUM tenant.
- Backfill tenant_id safely if adding tenant_id.
- Do not enable strict RLS until the API has been verified tenant-aware.
- Generate/apply schema with the current project Drizzle command.

5. Tests
- Add WhatsApp dispatch tests: SENT, retry/PENDING, FAILED, SKIPPED.
- Add client portal cross-client access denial test.
- Add technician cross-project access denial test.
- Add audit log mutation verification test or script.
- Add full acceptance workflow script.

Run:
- pnpm run typecheck
- pnpm run build
- current test command
- current Drizzle push command

Return:
- files created
- files modified
- schema changes
- tests added
- commands run
- pass/fail results
- blockers
- any human approval required

Do not print secrets or environment variable values.
```

## Final reporting format

Replit should return:

```text
STATUS: PASS | PARTIAL | BLOCKED

FILES CREATED:

FILES MODIFIED:

DATABASE CHANGES:

TESTS ADDED:

COMMANDS RUN:

RESULTS:

BLOCKERS:

HUMAN APPROVAL NEEDED:
```
