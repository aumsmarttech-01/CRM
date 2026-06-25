# Phase 5 Next Action Prompt

Use this prompt in Replit AI to continue the build with minimal human-in-the-loop.

```text
Continue AUM CRM Phase 5 from the current working codebase.

Goal:
Move from Phase 4 functional wiring into production-platform implementation across backend and frontend.

Rules:
- Do not ask for approval unless the action involves secrets, destructive database changes, production cutover, real payroll release, real payment action, or real client notification blast.
- Do not print secrets or environment variable values.
- Prefer non-destructive schema additions first.
- Keep the app compiling after each step.
- Run typecheck/build before reporting completion.

Step 1: Stabilize Phase 4
- Confirm the Phase 4 full wiring files exist and compile:
  - audit logs schema/service/middleware/route/page
  - import center schema/API/page
  - security middleware
  - project profitability route/page
  - executive dashboard route/page
  - technician scoping helper
  - client portal scoping additions
  - payroll seed script
  - WhatsApp verification script
  - acceptance workflow script
- Fix any TypeScript or import errors.

Step 2: Add tenant scaffold without breaking single-company mode
- Create tenants schema if missing.
- Create tenant_users schema if missing.
- Create a default AUM tenant seed/bootstrap script.
- Add tenant context middleware that resolves a default tenant when no multi-tenant header/domain is configured.
- Do NOT require tenant_id on every table yet unless the backfill is already complete.
- Add documentation explaining staged tenant rollout.

Step 3: Add backend service layer files
Create service modules if missing:
- artifacts/api-server/src/services/payroll-engine.ts
- artifacts/api-server/src/services/project-cost-engine.ts
- artifacts/api-server/src/services/workflow-engine.ts
- artifacts/api-server/src/services/executive-kpi.service.ts

Payroll engine must support:
- monthly salaried staff
- casual daily-rate staff
- Michael at KES 700/day
- employee advances
- leave deductions/adjustments where data exists
- attendance-driven day count where attendance events/timesheets exist

Project cost engine must aggregate:
- invoice revenue
- collected payments
- outstanding balance
- material costs
- labor/payroll costs
- subcontractor costs
- equipment costs
- travel costs
- misc costs
- gross profit
- margin percentage

Workflow engine must validate:
- work order closure requires completion proof where required
- project closure requires no critical open compliance
- ticket closure requires SOP completion where configured

Step 4: Add frontend pages or enhance existing pages
- Executive dashboard with finance, operations, HR, compliance, and collections cards/charts.
- Project profitability detail page.
- Payroll run review page showing monthly staff and casual daily-rate calculations.
- Technician My Work view filtered to assigned work only.
- Client portal views scoped to own projects, invoices, tickets, AMC, and documents.

Step 5: Add verification scripts/tests
Create or enhance:
- scripts/src/verify-audit-logs.ts
- scripts/src/verify-client-scoping.ts
- scripts/src/verify-technician-scoping.ts
- scripts/src/verify-acceptance-workflow.ts
- WhatsApp dispatch tests covering SENT, retry/PENDING, FAILED, SKIPPED.

Step 6: Backup and deployment scripts
Create:
- scripts/backup-pre-deploy.sh
- scripts/backup-post-import.sh
- docs/production-backup-restore.md

Backup scripts must read DATABASE_URL/SUPABASE_DATABASE_URL from env and must never print the URL.

Step 7: Run verification
Run:
- pnpm run typecheck
- pnpm run build
- current test command if available
- current Drizzle push command only after non-destructive schema changes are confirmed

Return exactly this report:

STATUS: PASS | PARTIAL | BLOCKED

FILES CREATED:

FILES MODIFIED:

DATABASE CHANGES:

TESTS/SCRIPTS ADDED:

COMMANDS RUN:

RESULTS:

BLOCKERS:

HUMAN APPROVAL NEEDED:
```

## Owner handoff

After Replit returns the report, paste it back into ChatGPT. Use the report to decide the next iteration.
