# Today Functional MVP Checklist

Goal: make AUM CRM functional today by wiring the minimum project-centered workflow first, then adding hardening items after the app runs.

## Non-negotiable rule

Do not add more standalone schemas until the following are wired:

1. projects
2. users/RBAC or existing user model mapping
3. audit_logs
4. documents
5. project workflow services
6. invoice/payment recalculation
7. attendance-to-timesheet/payroll logic

## Today MVP Scope

The functional system today should support this end-to-end workflow:

Lead -> Quotation -> Project -> Work Order -> Attendance -> Completion Proof -> Invoice -> Payment -> Review Request

## Phase 1: Stabilize schema

Tasks:

- Export every schema file from the central schema index.
- Ensure all new tables use text IDs.
- Do not use uuid columns in new tables unless the existing database already uses uuid.
- Remove duplicate employees definition from operations.ts.
- Keep existing employeesTable as canonical HR employee table.
- Keep existing invoices, notifications, review_requests, client_feedback, and job_completion_proofs as canonical.

## Phase 2: Add/confirm critical missing tables

Add these tables if not already present:

- projects
- users
- roles
- permissions
- user_roles
- role_permissions
- audit_logs
- documents
- stock_movements
- leave_requests
- employee_advances

## Phase 3: Backend service implementation order

1. Project service
   - create project
   - create project from accepted quotation
   - project summary
   - project cost summary
   - request closure
   - close project after compliance checks

2. Finance service
   - create invoice
   - add invoice item
   - recalculate invoice totals
   - record payment
   - update invoice status
   - trigger review request when paid

3. Work order service
   - create work order
   - assign employees
   - update status
   - attach SOP
   - approve completion proof

4. Attendance service
   - create attendance event
   - offline sync using client_event_id
   - generate timesheet entries

5. Payroll service
   - derive payroll from approved timesheets
   - apply advances
   - generate payroll entries

6. Compliance service
   - create compliance record
   - mark overdue
   - approve compliance
   - block ticket/project closure if incomplete

7. Costing service
   - aggregate project_costs
   - create labor cost from timesheets
   - create material cost from stock movements

## Phase 4: Required API groups

- /api/projects
- /api/work-orders
- /api/tickets
- /api/sops
- /api/compliance
- /api/attendance
- /api/timesheets
- /api/payroll
- /api/inventory
- /api/invoices
- /api/payments
- /api/dashboards

## Phase 5: Closure rules

Ticket/project closure must be blocked when:

- required SOP steps are incomplete
- compliance records are not approved
- completion proof is pending or rejected
- critical challenges remain open
- required invoice/payment rule is not satisfied where applicable

## Phase 6: Dashboard MVP

Build these summary endpoints first:

- GET /api/projects/:id/summary
- GET /api/projects/:id/profitability
- GET /api/dashboards/executive
- GET /api/dashboards/operations
- GET /api/dashboards/finance

## Phase 7: User tasks required in Replit

The owner must confirm:

- exact path of canonical employees schema file
- exact path of schema index file
- exact path of Express app entry point
- current database migration command
- current dev command
- Supabase DATABASE_URL is present in Replit Secrets

## Acceptance test

The MVP is functional only when all of these pass:

1. Create client.
2. Create lead.
3. Create quotation.
4. Accept quotation and create project.
5. Create work order under project.
6. Assign technician.
7. Submit attendance event.
8. Submit completion proof.
9. Approve proof.
10. Create invoice.
11. Record payment.
12. Invoice becomes PAID.
13. Review request row is created.
14. Project profitability endpoint shows revenue, costs, gross profit, and margin.
