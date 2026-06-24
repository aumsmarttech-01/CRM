# AUM CRM Project-Centered SaaS Architecture

This document defines the production architecture for wiring the CRM/ERP schemas around the `projects` table.

## 1. Architecture Diagram

```text
Tenant / Company
  |
  +-- Users / Roles / Permissions
  |     |
  |     +-- Employees
  |     +-- Client Users
  |
  +-- Clients
        |
        +-- Leads
        |     |
        |     +-- Quotations
        |           |
        |           +-- Projects
        |                 |
        |                 +-- Sites
        |                 |     |
        |                 |     +-- Work Orders
        |                 |           |
        |                 |           +-- Work Order Assignments
        |                 |           +-- Attendance Events
        |                 |           +-- Job SOPs / SOP Steps
        |                 |           +-- Job Completion Proofs
        |                 |           +-- Material Issues / Stock Movements
        |                 |           +-- Project Costs
        |                 |
        |                 +-- Service Tickets
        |                 |     |
        |                 |     +-- Ticket SOPs / Ticket SOP Steps
        |                 |     +-- Ticket Comments
        |                 |     +-- Compliance Checks
        |                 |
        |                 +-- Compliance Records
        |                 +-- Challenges / Risks
        |                 +-- Invoices
        |                 |     |
        |                 |     +-- Invoice Items
        |                 |     +-- Payments
        |                 |
        |                 +-- Review Requests
        |                 +-- Client Feedback
        |                 +-- Documents
        |
        +-- AMC Contracts
              |
              +-- AMC Visits
                    |
                    +-- Work Orders
                    +-- Completion Proofs
                    +-- Costs
```

## 2. Current Schema Assessment

### Strong areas

- CRM flow exists through clients, leads, quotations, follow ups, and service categories.
- Finance exists through document counters, invoices, invoice items, and payments.
- Service desk exists through service tickets, ticket SOPs, ticket SOP steps, and ticket comments.
- SOP governance exists through SOP templates, template steps, job SOPs, and job SOP steps.
- Operations exists through sites, work orders, assignments, attendance events, project costs, and completion proofs.
- Customer success exists through review requests and client feedback.
- Compliance and challenge tracking exist.
- Notifications/app settings can act as a transactional outbox.

### Missing relationships

The following relationships should exist in service logic immediately, and later as foreign keys after migration stabilization:

- `projects.client_id -> clients.id`
- `projects.quotation_id -> quotations.id`
- `projects.service_category_id -> service_categories.id`
- `sites.project_id -> projects.id`
- `work_orders.project_id -> projects.id`
- `work_orders.site_id -> sites.id`
- `work_orders.service_ticket_id -> service_tickets.id`
- `service_tickets.project_id -> projects.id`
- `ticket_sops.ticket_id -> service_tickets.id`
- `job_sops.project_id -> projects.id`
- `job_sops.work_order_id -> work_orders.id`
- `attendance_events.employee_id -> employees.id`
- `attendance_events.work_order_id -> work_orders.id`
- `project_costs.project_id -> projects.id`
- `project_costs.work_order_id -> work_orders.id`
- `invoices.project_id -> projects.id`
- `invoices.quotation_id -> quotations.id`
- `payments.invoice_id -> invoices.id`
- `review_requests.project_id -> projects.id`
- `review_requests.invoice_id -> invoices.id`
- `client_feedback.project_id -> projects.id`
- `compliance_records.project_id -> projects.id`
- `challenges.project_id -> projects.id`
- `job_completion_proofs.project_id -> projects.id`
- `job_completion_proofs.work_order_id -> work_orders.id` should be added.

### Missing tables

Required for production readiness:

1. `tenants`
2. `users`
3. `roles`
4. `permissions`
5. `user_roles`
6. `role_permissions`
7. `audit_logs`
8. `documents`
9. `projects`
10. `amc_contracts`
11. `stock_movements`
12. `suppliers`
13. `purchase_orders`
14. `purchase_order_items`
15. `goods_receipts`
16. `leave_requests`
17. `employee_advances`
18. `timesheets`
19. `timesheet_entries`
20. `payroll_runs`
21. `payroll_entries`
22. `payment_allocations` for future multi-invoice payments.

### Weak design areas

- Some schemas use free-text user references such as `assigned_to`, `created_by`, `approved_by`, `reviewed_by`, and `received_by`. These should reference `users.id` in application logic.
- `photo_urls` as text is weak. Use `documents` or `jsonb`.
- `is_read` in notifications should be boolean, not text.
- Inventory should not depend only on `inventory_items.quantity_available`. Stock must be movement-led.
- Existing operations drafts must not redefine `employees`. Keep the canonical HR employee table.
- Avoid mixing UUID database columns with text IDs. Existing application convention is text IDs.
- Ticket closure, project closure, payroll approval, and invoice payment need business rules, not just CRUD APIs.

## 3. Required Database Improvements

### projects

Minimum production fields:

```text
id
project_number
client_id
quotation_id
service_category_id
project_name
description
status
priority
project_manager_id
start_date
target_completion_date
completed_at
contract_value
budget_amount
created_by
created_at
updated_at
```

Recommended statuses:

```text
DRAFT
PLANNING
ACTIVE
ON_HOLD
PENDING_CLIENT
PENDING_COMPLIANCE
PENDING_CLOSURE
COMPLETED
CANCELLED
```

### users and RBAC

Use one internal identity table for staff, then map employees to users.

```text
users
- id
- tenant_id
- name
- email
- password_hash or auth_user_id
- status
- last_login_at
- created_at

roles
- id
- tenant_id
- name
- description

permissions
- id
- module
- action

user_roles
- user_id
- role_id

role_permissions
- role_id
- permission_id
```

### documents

Use for photos, proof files, compliance certificates, signed forms, invoices, quotations, payslips, and client attachments.

```text
documents
- id
- tenant_id
- entity_type
- entity_id
- document_type
- file_name
- file_url
- mime_type
- file_size
- uploaded_by
- created_at
```

### stock_movements

```text
stock_movements
- id
- tenant_id
- item_id
- movement_type
- quantity
- unit_cost
- project_id
- work_order_id
- reference_type
- reference_id
- notes
- created_by
- created_at
```

Movement types:

```text
PURCHASE_RECEIPT
PROJECT_ISSUE
PROJECT_RETURN
TRANSFER_IN
TRANSFER_OUT
ADJUSTMENT
DAMAGED
LOST
```

### payroll extension

```text
timesheets
- id
- tenant_id
- employee_id
- period_start
- period_end
- status
- regular_hours
- overtime_hours
- approved_by
- approved_at

payroll_runs
- id
- tenant_id
- payroll_no
- period_start
- period_end
- status
- gross_pay_total
- deductions_total
- advances_total
- net_pay_total

payroll_entries
- id
- payroll_run_id
- employee_id
- regular_pay
- overtime_pay
- allowances
- deductions
- advances_recovered
- net_pay
```

## 4. Backend Structure: Node.js / Express

Recommended folder structure:

```text
src/
  app.ts
  server.ts
  db/
    index.ts
    schema/
  middleware/
    auth.middleware.ts
    tenant.middleware.ts
    rbac.middleware.ts
    audit.middleware.ts
    error.middleware.ts
  modules/
    clients/
      clients.routes.ts
      clients.controller.ts
      clients.service.ts
    leads/
    quotations/
    projects/
    work-orders/
    tickets/
    sops/
    compliance/
    attendance/
    payroll/
    inventory/
    finance/
    documents/
    notifications/
    dashboards/
  shared/
    errors.ts
    pagination.ts
    validators.ts
    transaction.ts
```

## 5. Required APIs

### Projects

```text
GET    /api/projects
POST   /api/projects
GET    /api/projects/:id
PATCH  /api/projects/:id
POST   /api/projects/:id/activate
POST   /api/projects/:id/hold
POST   /api/projects/:id/request-closure
POST   /api/projects/:id/close
GET    /api/projects/:id/summary
GET    /api/projects/:id/costs
GET    /api/projects/:id/profitability
```

### Tickets

```text
GET    /api/tickets
POST   /api/tickets
GET    /api/tickets/:id
PATCH  /api/tickets/:id
POST   /api/tickets/:id/assign
POST   /api/tickets/:id/start
POST   /api/tickets/:id/complete-sop-step
POST   /api/tickets/:id/request-closure
POST   /api/tickets/:id/close
POST   /api/tickets/:id/comments
```

### SOPs

```text
GET    /api/sop-templates
POST   /api/sop-templates
POST   /api/projects/:projectId/sops/from-template
POST   /api/work-orders/:workOrderId/sops/from-template
POST   /api/tickets/:ticketId/sops/from-template
PATCH  /api/sop-steps/:stepId/status
POST   /api/sop-steps/:stepId/evidence
```

### Compliance

```text
GET    /api/compliance
POST   /api/compliance
PATCH  /api/compliance/:id
POST   /api/compliance/:id/submit
POST   /api/compliance/:id/approve
POST   /api/compliance/:id/cancel
GET    /api/projects/:id/compliance-status
```

### Attendance

```text
POST   /api/attendance/events
POST   /api/attendance/offline-sync
GET    /api/attendance/employee/:employeeId
GET    /api/work-orders/:id/attendance
POST   /api/timesheets/generate
POST   /api/timesheets/:id/submit
POST   /api/timesheets/:id/approve
```

### Payroll

```text
POST   /api/payroll-runs
GET    /api/payroll-runs
GET    /api/payroll-runs/:id
POST   /api/payroll-runs/:id/calculate
POST   /api/payroll-runs/:id/approve
POST   /api/payroll-runs/:id/mark-paid
```

### Inventory / Materials

```text
GET    /api/inventory/items
POST   /api/inventory/items
POST   /api/inventory/stock-movements
POST   /api/work-orders/:id/issue-materials
POST   /api/work-orders/:id/return-materials
GET    /api/projects/:id/material-costs
```

### Finance

```text
POST   /api/invoices
GET    /api/invoices
GET    /api/invoices/:id
POST   /api/invoices/:id/items
POST   /api/invoices/:id/payments
POST   /api/invoices/:id/recalculate
POST   /api/invoices/:id/send
GET    /api/finance/aging
GET    /api/finance/collections
```

### Dashboards

```text
GET /api/dashboards/executive
GET /api/dashboards/projects
GET /api/dashboards/operations
GET /api/dashboards/finance
GET /api/dashboards/hr
GET /api/dashboards/client-portal
```

## 6. Service Layer Logic

### project.service.ts

Responsibilities:

- Create project from accepted quotation.
- Update project lifecycle status.
- Enforce compliance before closure.
- Aggregate project cost and profitability.
- Produce project dashboard summary.

### ticket.service.ts

Responsibilities:

- Create ticket under client/project.
- Assign ticket.
- Attach ticket SOP.
- Check SOP completion.
- Check compliance requirements.
- Close only when all closure rules pass.

### attendance.service.ts

Responsibilities:

- Validate time-in/time-out sequence.
- Validate geofence when site has coordinates.
- Accept offline events with idempotency.
- Generate daily summaries or timesheet entries.

### payroll.service.ts

Responsibilities:

- Pull approved timesheets.
- Calculate regular/overtime pay.
- Apply advances and deductions.
- Generate payroll entries.
- Lock payroll run after approval.

### costing.service.ts

Responsibilities:

- Convert material issues into project costs.
- Convert approved timesheet entries into labor costs.
- Aggregate all project costs.
- Compute gross margin.

### compliance.service.ts

Responsibilities:

- Create mandatory compliance records for project/ticket type.
- Mark overdue records.
- Approve submitted records.
- Block ticket/project closure if required records are not approved.

## 7. Business Logic Functions

### calculateProjectTotalCost

```ts
async function calculateProjectTotalCost(projectId: string) {
  const materialCost = await db.projectCosts.sum({
    projectId,
    costType: "material",
  });

  const laborCost = await db.projectCosts.sum({
    projectId,
    costType: "labor",
  });

  const equipmentCost = await db.projectCosts.sum({
    projectId,
    costType: "equipment",
  });

  const subcontractorCost = await db.projectCosts.sum({
    projectId,
    costType: "subcontractor",
  });

  const travelCost = await db.projectCosts.sum({
    projectId,
    costType: "travel",
  });

  const miscCost = await db.projectCosts.sum({
    projectId,
    costType: "misc",
  });

  const totalCost = materialCost + laborCost + equipmentCost + subcontractorCost + travelCost + miscCost;

  const invoiceRevenue = await db.invoices.sumPaidOrInvoiced(projectId);

  return {
    projectId,
    materialCost,
    laborCost,
    equipmentCost,
    subcontractorCost,
    travelCost,
    miscCost,
    totalCost,
    revenue: invoiceRevenue,
    grossProfit: invoiceRevenue - totalCost,
    grossMarginPercent: invoiceRevenue > 0 ? ((invoiceRevenue - totalCost) / invoiceRevenue) * 100 : 0,
  };
}
```

### derivePayrollFromAttendance

```ts
async function derivePayrollFromAttendance({ employeeId, periodStart, periodEnd }: {
  employeeId: string;
  periodStart: string;
  periodEnd: string;
}) {
  const events = await attendanceRepository.findEvents(employeeId, periodStart, periodEnd);
  const employee = await employeeRepository.findById(employeeId);

  const days = groupEventsByDay(events);

  let regularHours = 0;
  let overtimeHours = 0;

  for (const day of days) {
    const workedHours = calculateWorkedHoursFromEvents(day.events);
    const regular = Math.min(workedHours, 8);
    const overtime = Math.max(workedHours - 8, 0);

    regularHours += regular;
    overtimeHours += overtime;
  }

  const regularPay = regularHours * Number(employee.hourlyRate ?? 0);
  const overtimePay = overtimeHours * Number(employee.overtimeHourlyRate ?? employee.hourlyRate ?? 0);
  const grossPay = regularPay + overtimePay;

  return {
    employeeId,
    periodStart,
    periodEnd,
    regularHours,
    overtimeHours,
    regularPay,
    overtimePay,
    grossPay,
  };
}
```

### enforceComplianceBeforeClosure

```ts
async function enforceComplianceBeforeClosure(entityType: "PROJECT" | "TICKET", entityId: string) {
  const compliance = await complianceRepository.findRequiredForEntity(entityType, entityId);

  const blocking = compliance.filter((record) =>
    ["PENDING", "IN_PROGRESS", "SUBMITTED", "OVERDUE"].includes(record.status)
  );

  if (blocking.length > 0) {
    throw new BusinessRuleError("Closure blocked by incomplete compliance records", {
      entityType,
      entityId,
      blockingComplianceIds: blocking.map((x) => x.id),
    });
  }

  return true;
}
```

### closeTicket

```ts
async function closeTicket(ticketId: string, actorUserId: string) {
  return db.transaction(async (tx) => {
    const ticket = await ticketRepository.findById(ticketId, tx);

    await sopService.assertTicketSopComplete(ticketId, tx);
    await complianceService.enforceComplianceBeforeClosure("TICKET", ticketId, tx);

    await ticketRepository.updateStatus(ticketId, "CLOSED", tx);

    await auditService.log({
      actorUserId,
      action: "TICKET_CLOSED",
      entityType: "service_ticket",
      entityId: ticketId,
    }, tx);

    await notificationService.enqueue({
      eventType: "TICKET_CLOSED",
      entityType: "service_ticket",
      entityId: ticketId,
      channel: "SYSTEM",
      title: "Ticket closed",
      body: `Ticket ${ticket.ticketNumber} has been closed.`,
    }, tx);
  });
}
```

## 8. Workflow Rules

### Ticket to SOP to compliance to closure

```text
Ticket OPEN
  -> Assign technician / owner
  -> Attach SOP template
  -> Execute SOP steps
  -> Upload evidence where required
  -> Submit required compliance records
  -> Supervisor review
  -> All SOP steps complete?
  -> All compliance approved?
  -> Completion proof approved?
  -> Ticket CLOSED
```

Closure blockers:

- Any required SOP step not completed.
- Any required compliance record not approved.
- Any required completion proof rejected or pending.
- Any unresolved critical challenge linked to ticket/project.

### Attendance to labor to payroll

```text
Technician time_in
  -> Validate assignment
  -> Validate geofence
  -> Store attendance_event
Technician time_out
  -> Pair with time_in
  -> Calculate worked hours
  -> Generate timesheet entry
Supervisor approves timesheet
  -> Create labor project_cost
  -> Feed payroll_run
Payroll approved
  -> Lock payroll entries
```

### Project to cost aggregation

```text
Project ACTIVE
  -> Materials issued to work orders
  -> Stock movements created
  -> Material project_costs created
  -> Attendance approved
  -> Labor project_costs created
  -> Other costs entered
  -> Project cost summary calculated
  -> Revenue from invoices/payments compared
  -> Profitability dashboard updated
```

## 9. Production SaaS Features

### Multi-tenant design

Add `tenant_id` to every business table unless the deployment is permanently single-company.

Rules:

- Every query must filter by tenant_id.
- Every unique business number should be unique by tenant_id + number.
- RBAC should be tenant-scoped.
- Client users must only access their tenant and client_id.

### Role-based access

Permissions should be module/action based:

```text
projects:create
projects:read
projects:update
projects:close
invoices:approve
payroll:approve
attendance:manual_adjust
compliance:approve
```

### Offline support for attendance

Add fields:

```text
client_event_id
sync_status
synced_at
device_timestamp
device_id
```

Rules:

- Device generates a unique client_event_id.
- Server accepts duplicate sync safely using unique tenant_id + client_event_id.
- Server flags suspicious GPS/time drift for review.

### Audit logs

Audit all critical actions:

- Login attempts
- Role changes
- Project status changes
- Ticket closure
- Compliance approval
- Invoice creation/update
- Payment recording
- Payroll approval
- Manual attendance changes
- Stock adjustments

### Background workers

Required jobs:

- Notification outbox dispatcher
- Overdue invoice marker
- Compliance overdue marker
- Follow-up reminder generator
- AMC visit scheduler
- Attendance anomaly detector
- Dashboard snapshot refresher

## 10. Prioritized Build Roadmap

### Step 1: Stabilize schema

- Remove duplicate employee definitions.
- Confirm all new IDs use text convention.
- Export all schema files from schema index.
- Add projects, users/RBAC, audit_logs, documents.

### Step 2: Build project backbone

- Implement project CRUD.
- Implement quotation accepted -> project creation.
- Implement project summary endpoint.
- Implement project status transitions.

### Step 3: Wire service execution

- Implement tickets.
- Implement ticket SOP attachment.
- Implement SOP step completion.
- Implement proof upload/review.
- Enforce ticket closure rules.

### Step 4: Wire operations and attendance

- Implement work orders and assignments.
- Implement attendance event capture.
- Implement offline sync.
- Generate timesheets.
- Approve timesheets.

### Step 5: Wire costing

- Add stock movements.
- Issue materials to work orders.
- Create material project costs.
- Create labor project costs from approved timesheets.
- Build project profitability endpoint.

### Step 6: Wire finance

- Implement document counters.
- Implement invoice generation from quotation/project.
- Implement payment recording.
- Recalculate invoice balances.
- Trigger review request on paid invoice.

### Step 7: Wire compliance and governance

- Implement compliance records.
- Add overdue compliance sweep.
- Block project/ticket closure until approved.
- Add challenge escalation.

### Step 8: Build dashboards

- Executive dashboard.
- Operations dashboard.
- Finance dashboard.
- HR dashboard.
- Client portal dashboard.

### Step 9: SaaS hardening

- Add tenant_id everywhere.
- Add RBAC middleware.
- Add audit logging middleware.
- Add rate limiting.
- Add backups and restore testing.
- Add security monitoring.

## 11. First Production Workflow to Implement

Start here:

```text
Lead -> Quotation -> Project -> Work Order -> Attendance -> Completion Proof -> Invoice -> Payment -> Review Request
```

This workflow connects sales, operations, HR, finance, and customer success. It gives the platform immediate operational value and creates the reporting spine for the rest of the SaaS product.
