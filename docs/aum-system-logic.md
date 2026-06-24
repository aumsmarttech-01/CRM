# AUM CRM ERP System Logic

## Purpose

This document defines the operational logic for the AUM CRM ERP build after Supabase PostgreSQL migration.

The product must operate around this hierarchy:

```text
Client -> Project -> Site -> Work Order -> Assignment -> Attendance -> Timesheet -> Payroll -> Project Costing -> Reporting
```

## Core rule

Every business action must belong to a clear operational object:

- Client owns projects.
- Project owns sites.
- Site owns work orders.
- Work orders own assignments, attendance, material usage, labor usage, and completion evidence.
- Attendance feeds timesheets.
- Timesheets feed payroll.
- Materials and labor feed project cost.
- Payroll, materials, invoices, and payments feed profitability.

## 1. Project and site costing logic

### Cost sources

A project cost can come from:

- Material request
- Inventory issue
- Technician labor
- Timesheet labor
- Subcontractor cost
- Travel cost
- Equipment cost
- Miscellaneous approved expense

### Cost calculation

```ts
projectCost.totalCost = projectCost.quantity * projectCost.unitCost;
```

### Project profitability

```ts
projectRevenue = sum(invoices.totalAmount where projectId = project.id and status != 'cancelled');
projectCost = sum(projectCosts.totalCost where projectId = project.id);
grossProfit = projectRevenue - projectCost;
grossMarginPercent = projectRevenue > 0 ? (grossProfit / projectRevenue) * 100 : 0;
```

### Site profitability

```ts
siteCost = sum(projectCosts.totalCost where siteId = site.id);
siteLaborCost = sum(projectCosts.totalCost where siteId = site.id and costType = 'labor');
siteMaterialCost = sum(projectCosts.totalCost where siteId = site.id and costType = 'material');
```

## 2. Work order logic

### Work order states

```text
draft -> assigned -> in_progress -> waiting_material -> completed -> approved -> closed
```

### Assignment rule

A technician can only view and update work orders assigned to them, unless their role grants broader access.

```ts
canAccessWorkOrder(user, workOrder) {
  if (user.role in ['admin', 'operations_manager', 'project_manager']) return true;
  if (user.role === 'technician') return workOrder.assignedEmployeeIds.includes(user.employeeId);
  return false;
}
```

## 3. Attendance logic

Attendance is Smart Office SOS-style and must capture:

- Employee
- Project
- Site
- Work order
- Event type
- Time
- GPS location
- Source device
- Geofence status
- Optional photo proof

### Attendance event types

```text
time_in
break_start
break_end
time_out
```

### Attendance validation

```ts
validateAttendanceEvent(event) {
  assert(event.employeeId);
  assert(event.eventType);
  assert(event.eventAt);

  if (event.siteId) {
    calculateDistanceFromSite(event.latitude, event.longitude, site.latitude, site.longitude);
    event.isWithinGeofence = distance <= site.geofenceRadiusMeters;
  }

  preventDuplicateEvent(employeeId, eventType, eventAt);
  enforceValidSequence(employeeId, eventType, eventAt);
}
```

### Attendance sequence

```text
time_in must happen before break_start
break_start must happen before break_end
time_out must happen after time_in
only one open time_in per employee per day
```

## 4. Timesheet logic

Timesheets are generated from approved attendance events.

```ts
regularHours = min(totalWorkedHours, standardDailyHours);
overtimeHours = max(totalWorkedHours - standardDailyHours, 0);
laborCost = (regularHours * employee.hourlyRate) + (overtimeHours * employee.overtimeHourlyRate);
```

Every timesheet entry should optionally connect to:

- Project
- Site
- Work order

When approved, labor cost must create a project cost record.

```ts
onTimesheetApproved(timesheetEntry) {
  createProjectCost({
    projectId: timesheetEntry.projectId,
    siteId: timesheetEntry.siteId,
    workOrderId: timesheetEntry.workOrderId,
    costType: 'labor',
    quantity: timesheetEntry.regularHours + timesheetEntry.overtimeHours,
    unitCost: blendedHourlyCost,
    totalCost: timesheetEntry.laborCost,
    sourceType: 'timesheet_entry',
    sourceId: timesheetEntry.id
  });
}
```

## 5. Materials logic

### Material request states

```text
draft -> submitted -> approved -> issued -> consumed -> closed
```

When materials are issued to a work order, create project cost entries.

```ts
onMaterialIssued(item) {
  createProjectCost({
    projectId: materialRequest.projectId,
    siteId: materialRequest.siteId,
    workOrderId: materialRequest.workOrderId,
    costType: 'material',
    quantity: item.issuedQuantity,
    unitCost: item.unitCost,
    totalCost: item.issuedQuantity * item.unitCost,
    sourceType: 'material_request_item',
    sourceId: item.id
  });
}
```

## 6. Payroll logic

Payroll depends on approved timesheets and approved advances.

### Payroll calculation

```ts
basicPay = regularHours * employee.hourlyRate;
overtimePay = overtimeHours * employee.overtimeHourlyRate;
grossPay = basicPay + overtimePay + allowances;
netPay = grossPay - deductions - advancesRecovered;
```

### Advance logic

```ts
advanceBalance = approvedAmount - recoveredAmount;
recoveryThisRun = min(configuredRecoveryAmount, advanceBalance, grossPay);
```

When payroll is approved:

- Lock payroll entries.
- Generate payslip document metadata.
- Record payment entries when paid.
- Reduce employee advance balance when recovered.

## 7. Leave logic

### Leave states

```text
draft -> submitted -> approved -> rejected -> cancelled
```

### Leave validation

```ts
validateLeaveRequest(request) {
  assert(request.employeeId);
  assert(request.startDate <= request.endDate);
  assert(request.totalDays > 0);
  preventOverlap(employeeId, startDate, endDate);
}
```

Approved leave should affect attendance and payroll.

```ts
if (leave.status === 'approved') {
  markEmployeeUnavailable(employeeId, startDate, endDate);
  includeLeaveInPayroll(employeeId, leaveType, totalDays);
}
```

## 8. Document logic

Use one reusable document table for:

- Payslips
- Leave attachments
- Employee documents
- Work order evidence
- Site documents
- Project documents
- Material request documents
- Payment receipts
- Advance approvals

Every document must include:

```text
entityType
entityId
documentType
fileName
filePath
mimeType
sizeBytes
uploadedByUserId
isConfidential
```

## 9. Role access logic

```ts
admin: full access
executive: read and export reports
operations_manager: projects, sites, work orders, attendance, materials
project_manager: own projects, sites, work orders, costs
technician: assigned work orders and own attendance
hr: employees, attendance, leave, payroll view
finance: project costs, invoices, payroll, payments, reports
inventory_manager: materials, inventory, material requests
sales: clients, leads, quotations
support: tickets and client updates
client_portal_user: own tickets, documents, and public updates only
```

## 10. Dashboard logic

### Operations dashboard

```text
Active work orders
Pending material requests
Technicians on site today
Late or missing time-ins
Completed work orders awaiting approval
```

### Finance dashboard

```text
Project revenue
Project cost
Gross profit
Invoice aging
Payroll due
Advances outstanding
```

### HR dashboard

```text
Employees active
Attendance today
Leave pending approval
Payroll readiness
Advances pending approval
```

### Executive dashboard

```text
Revenue
Gross margin
Project profitability
Labor cost
Material cost
Cash due
AMC renewals
Sales pipeline
```

## 11. Build sequence

1. Confirm Supabase data migration and smoke test.
2. Implement RBAC tables and seed roles.
3. Implement employees and sites.
4. Implement work orders and assignments.
5. Implement attendance events.
6. Generate timesheets from attendance.
7. Implement payroll runs, payroll entries, advances, and payments.
8. Implement leave requests and approval workflow.
9. Implement project costs from materials and labor.
10. Implement reports and dashboards.

## 12. Non-negotiables

- No Prisma.
- No Supabase Auth.
- No secrets in code.
- No frontend direct database access.
- All access goes through API authorization.
- Drizzle schema is the database source of truth.
- Every sensitive HR/payroll document must be access controlled.
