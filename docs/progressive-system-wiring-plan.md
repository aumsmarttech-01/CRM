# AUM CRM Progressive System Wiring Plan

This plan turns the uploaded Drizzle schemas into one coherent CRM/ERP platform without rushing into unsafe migrations or duplicate tables.

## Guiding Principles

1. Drizzle is the source of truth for schema.
2. Supabase is the PostgreSQL host, not the authentication or data-access model unless explicitly migrated later.
3. Keep text IDs across new modules to match the existing CRM convention.
4. Do not create duplicate master tables.
5. Preserve client users separately from internal staff users unless a later identity migration intentionally unifies them.
6. Wire modules through service-layer workflows first; add strict foreign keys only after the existing schema is fully consolidated.
7. All critical business actions should create audit logs and notifications.

## Canonical Core Tables

The following tables should be treated as canonical based on the schemas provided so far:

- clients
- client_users
- leads
- service_categories
- quotations
- quotation_items
- document_counters
- invoices
- invoice_items
- payments
- service_tickets
- ticket_sops
- ticket_sop_steps
- ticket_comments
- sop_templates
- sop_template_steps
- job_sops
- job_sop_steps
- amc_visits
- employees
- attendance
- payroll
- hr_tasks
- inventory_items
- follow_ups
- notifications
- app_settings
- review_requests
- client_feedback
- challenges
- compliance_records
- job_completion_proofs

## Tables That Must Be Added or Consolidated Next

### 1. Projects

Projects are the operational backbone. Existing modules already reference project_id, so this must be added before deeper workflow wiring.

Recommended minimum fields:

- id
- project_number
- client_id
- quotation_id
- service_category_id
- project_name
- description
- status
- priority
- project_manager_id
- start_date
- target_completion_date
- completed_at
- budget_amount
- contract_value
- created_by
- created_at
- updated_at

### 2. Internal Users and RBAC

Many tables use assigned_to, created_by, approved_by, reviewed_by, received_by, technician_id, and staff_user_id. These need a consistent identity model.

Recommended tables:

- users
- roles
- permissions
- role_permissions
- user_roles
- user_permission_overrides
- module_access
- role_module_access

### 3. Audit Logs

Every critical business change should write to audit_logs.

Recommended fields:

- id
- actor_user_id
- actor_type
- action
- entity_type
- entity_id
- before
- after
- ip_address
- user_agent
- created_at

### 4. Documents

Photos, proofs, invoices, quotations, payslips, compliance files, signatures, and AMC reports should use one reusable documents table.

Recommended fields:

- id
- entity_type
- entity_id
- document_type
- file_name
- file_url
- mime_type
- file_size
- uploaded_by
- created_at

### 5. Stock Movements

Do not rely only on inventory_items.quantity_available. Add stock_movements for audit-safe inventory.

Recommended fields:

- id
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

### 6. HR Extensions

Add around the existing HR tables rather than replacing them:

- leave_requests
- employee_advances
- timesheets
- timesheet_entries

## Progressive Wiring Phases

## Phase 0: Consolidation Safety Pass

Goal: prevent schema conflicts before migration.

Tasks:

1. Confirm all schema files are exported from lib/db/src/schema/index.ts.
2. Remove or refactor any duplicate employees table definitions.
3. Ensure all new schema files use text IDs, not uuid columns.
4. Confirm canonical notifications, invoices, client_feedback, review_requests, and job_completion_proofs are not duplicated.
5. Keep existing employees, attendance, payroll, and hr_tasks as canonical HR tables.
6. Run Drizzle typecheck before generating migration.

Exit criteria:

- No duplicate table names.
- No duplicate enum names with different definitions.
- No uuid/text mismatch on new tables.
- Drizzle schema compiles.

## Phase 1: Core Backbone

Goal: create the central business spine.

Workflow spine:

Lead -> Quotation -> Project -> Work Order -> Completion Proof -> Invoice -> Payment -> Review Request -> Feedback

Tasks:

1. Add projects table.
2. Connect leads to quotations through lead_id.
3. Connect quotations to projects through quotation_id.
4. Connect invoices to projects and quotations.
5. Connect review_requests to project_id or invoice_id.
6. Connect client_feedback to project_id or invoice_id.
7. Add service_category_id to leads/projects later after migration stability.

Automation rules:

- Quotation ACCEPTED creates Project.
- Project COMPLETED creates Review Request.
- Invoice PAID creates Review Request if no prior matching row exists.
- Invoice OVERDUE creates Follow Up and Notification.

Exit criteria:

- A lead can become a quotation.
- An accepted quotation can create a project.
- A project can generate invoice and payment records.
- Paid invoice can trigger review request.

## Phase 2: Identity and RBAC

Goal: define who can see and do what.

Internal roles:

- Executive
- Finance
- HR
- Sales
- Operations Manager
- Project Manager
- Supervisor
- Technician

External roles:

- Client Admin
- Client Manager
- Client Viewer

Tasks:

1. Add users, roles, permissions, user_roles, role_permissions.
2. Map assigned_to, created_by, approved_by, reviewed_by, received_by fields to internal user IDs in service logic.
3. Keep client_users scoped to client_id.
4. Add module-level access checks in API routes.
5. Add audit_logs to all create/update/delete actions.

Exit criteria:

- Internal users have role-based module permissions.
- Client users can access only their client scope.
- Critical changes are audited.

## Phase 3: Operations Wiring

Goal: turn project records into field execution.

Workflow:

Project -> Site -> Work Order -> Assignment -> Attendance Events -> Completion Proof -> Approval -> Project Cost

Tasks:

1. Refactor operations schema to import canonical employees table.
2. Keep attendance_events as detailed punch log around existing attendance summary.
3. Add work_order_assignments if not already stable.
4. Link job_completion_proofs to work_order_id in a later safe migration.
5. Create project_costs from labor, materials, travel, subcontractors, equipment, and misc.
6. Add notifications for work order assignment and proof approval/rejection.

Exit criteria:

- Technician sees assigned work.
- Technician submits attendance and proof.
- Supervisor approves/rejects proof.
- Approved proof can update work order/project status.
- Costs flow into project profitability.

## Phase 4: Finance Wiring

Goal: make invoicing, payment, and collections reliable.

Tasks:

1. Use document_counters for quote/invoice numbering.
2. On invoice item change, recalculate subtotal, VAT, grand_total, balance_due.
3. On payment insert, recalculate amount_paid and balance_due.
4. Set invoice status automatically.
5. Create follow_up and notification when invoice becomes overdue.
6. Trigger review_requests when invoice becomes PAID.

Exit criteria:

- Partial payments work.
- Invoice status updates automatically.
- Outstanding and overdue balances are reportable.

## Phase 5: Inventory and Procurement

Goal: move inventory from static stock list to auditable stock control.

Tasks:

1. Add stock_movements.
2. Create stock movement when material is issued to project/work order.
3. Create project_costs rows from material usage.
4. Add suppliers and purchase_orders later.
5. Add reorder alerts using notifications.

Exit criteria:

- Stock quantity is derived from movements or reconciled safely.
- Project material cost is automatic.
- Low-stock alerts work.

## Phase 6: HR and Payroll Extensions

Goal: connect field attendance to payroll and employee controls.

Tasks:

1. Add leave_requests.
2. Add employee_advances.
3. Add timesheets and timesheet_entries.
4. Generate timesheets from attendance_events.
5. Connect approved timesheets to payroll.
6. Deduct approved advances from payroll.

Exit criteria:

- Leave approval workflow works.
- Advances can be approved and recovered.
- Timesheets support payroll calculation.

## Phase 7: Compliance, CX, and Governance

Goal: formalize quality, compliance, and customer success.

Tasks:

1. Use compliance_records for client/project requirements and due dates.
2. Use challenges as project issue/risk register.
3. Use client_feedback for complaints, compliments, suggestions, and ratings.
4. Use review_requests for Google review dedupe and tracking.
5. Use SOP tables for job and ticket execution governance.
6. Add notifications and follow_ups for overdue compliance and unresolved complaints.

Exit criteria:

- Overdue compliance triggers escalation.
- Complaints are tracked to resolution.
- Project challenges affect dashboard risk status.

## Phase 8: Dashboards

Build dashboards only after the core workflows are wired.

Executive dashboard:

- Revenue
- Cash received
- Outstanding invoices
- Project profitability
- Open critical challenges
- Open compliance items
- Average feedback rating
- Sales pipeline value

Operations dashboard:

- Active projects
- Work orders due
- Pending proof reviews
- Technician utilization
- Open challenges

Finance dashboard:

- Invoices by status
- Collections due
- Overdue balances
- Payments received
- Project margin

Sales dashboard:

- Leads by status
- Quotations by status
- Follow-ups due
- Conversion rate

Client portal dashboard:

- Client projects
- Tickets
- Invoices
- AMC visits
- Documents
- Feedback

## Immediate Implementation Checklist

1. Create projects schema.
2. Create users/RBAC schema or confirm existing users schema.
3. Create audit_logs schema.
4. Create documents schema.
5. Refactor operations.ts to remove duplicate employees table and use text IDs.
6. Export all schema files from schema index.
7. Run Drizzle typecheck.
8. Generate migration.
9. Run migration on Supabase development/staging database.
10. Seed roles, permissions, service categories, and document counters.
11. Build service-layer functions for quotation acceptance, invoice payment, proof approval, review request creation, and notification outbox.

## Do Not Do Yet

- Do not merge uuid-based operations schema as-is.
- Do not create duplicate employees, invoices, feedback, notifications, or review_requests tables.
- Do not expose Supabase database directly to clients.
- Do not hardcode secrets in the repo.
- Do not build dashboards before the workflows update source-of-truth tables correctly.

## Recommended First Workflow to Implement

Start with the revenue-to-delivery workflow:

Lead -> Quotation -> Project -> Invoice -> Payment -> Review Request

This gives the business immediate value and creates the core reporting spine for the rest of the ERP.
