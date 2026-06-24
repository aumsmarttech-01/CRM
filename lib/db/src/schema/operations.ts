import { relations } from "drizzle-orm";
import {
  boolean,
  date,
  index,
  integer,
  numeric,
  pgEnum,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
} from "drizzle-orm/pg-core";

const randomId = () => crypto.randomUUID();

export const attendanceEventType = pgEnum("attendance_event_type", [
  "time_in",
  "break_start",
  "break_end",
  "time_out",
]);

export const attendanceSource = pgEnum("attendance_source", [
  "web",
  "mobile",
  "kiosk",
  "manual",
  "offline_sync",
]);

export const approvalStatus = pgEnum("approval_status", [
  "draft",
  "submitted",
  "approved",
  "rejected",
  "cancelled",
]);

export const leaveType = pgEnum("leave_type", [
  "annual",
  "sick",
  "unpaid",
  "compassionate",
  "maternity",
  "paternity",
  "study",
  "other",
]);

export const projectCostType = pgEnum("project_cost_type", [
  "material",
  "labor",
  "equipment",
  "subcontractor",
  "travel",
  "misc",
]);

export const payrollStatus = pgEnum("payroll_status", [
  "draft",
  "processing",
  "approved",
  "paid",
  "cancelled",
]);

export const employees = pgTable("employees", {
  id: text("id").primaryKey().$defaultFn(randomId),
  staffUserId: text("staff_user_id"),
  employeeCode: text("employee_code").notNull(),
  firstName: text("first_name").notNull(),
  lastName: text("last_name").notNull(),
  email: text("email"),
  phone: text("phone"),
  jobTitle: text("job_title"),
  department: text("department"),
  baseSalary: numeric("base_salary", { precision: 14, scale: 2 }).notNull().default("0"),
  hourlyRate: numeric("hourly_rate", { precision: 14, scale: 2 }).notNull().default("0"),
  overtimeHourlyRate: numeric("overtime_hourly_rate", { precision: 14, scale: 2 }).notNull().default("0"),
  status: text("status").notNull().default("active"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  employeeCodeUnique: uniqueIndex("employees_employee_code_unique").on(table.employeeCode),
  statusIdx: index("employees_status_idx").on(table.status),
  staffUserIdx: index("employees_staff_user_idx").on(table.staffUserId),
}));

export const sites = pgTable("sites", {
  id: text("id").primaryKey().$defaultFn(randomId),
  clientId: text("client_id"),
  projectId: text("project_id"),
  name: text("name").notNull(),
  code: text("code"),
  address: text("address"),
  city: text("city"),
  postcode: text("postcode"),
  latitude: numeric("latitude", { precision: 10, scale: 7 }),
  longitude: numeric("longitude", { precision: 10, scale: 7 }),
  geofenceRadiusMeters: integer("geofence_radius_meters").notNull().default(150),
  status: text("status").notNull().default("active"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  clientIdx: index("sites_client_idx").on(table.clientId),
  projectIdx: index("sites_project_idx").on(table.projectId),
  statusIdx: index("sites_status_idx").on(table.status),
}));

export const workOrders = pgTable("work_orders", {
  id: text("id").primaryKey().$defaultFn(randomId),
  workOrderNo: text("work_order_no").notNull(),
  clientId: text("client_id"),
  projectId: text("project_id"),
  serviceTicketId: text("service_ticket_id"),
  siteId: text("site_id").references(() => sites.id),
  title: text("title").notNull(),
  description: text("description"),
  status: text("status").notNull().default("draft"),
  priority: text("priority").notNull().default("normal"),
  scheduledStartAt: timestamp("scheduled_start_at", { withTimezone: true }),
  scheduledEndAt: timestamp("scheduled_end_at", { withTimezone: true }),
  actualStartAt: timestamp("actual_start_at", { withTimezone: true }),
  actualEndAt: timestamp("actual_end_at", { withTimezone: true }),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  workOrderNoUnique: uniqueIndex("work_orders_no_unique").on(table.workOrderNo),
  clientIdx: index("work_orders_client_idx").on(table.clientId),
  projectIdx: index("work_orders_project_idx").on(table.projectId),
  ticketIdx: index("work_orders_service_ticket_idx").on(table.serviceTicketId),
  siteIdx: index("work_orders_site_idx").on(table.siteId),
  statusIdx: index("work_orders_status_idx").on(table.status),
}));

export const workOrderAssignments = pgTable("work_order_assignments", {
  id: text("id").primaryKey().$defaultFn(randomId),
  workOrderId: text("work_order_id").notNull().references(() => workOrders.id),
  employeeId: text("employee_id").notNull().references(() => employees.id),
  role: text("role").notNull().default("technician"),
  assignedAt: timestamp("assigned_at", { withTimezone: true }).notNull().defaultNow(),
  removedAt: timestamp("removed_at", { withTimezone: true }),
  assignedByUserId: text("assigned_by_user_id"),
  notes: text("notes"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  workOrderEmployeeUnique: uniqueIndex("work_order_assignments_order_employee_unique").on(table.workOrderId, table.employeeId),
  workOrderIdx: index("work_order_assignments_order_idx").on(table.workOrderId),
  employeeIdx: index("work_order_assignments_employee_idx").on(table.employeeId),
}));

export const attendanceEvents = pgTable("attendance_events", {
  id: text("id").primaryKey().$defaultFn(randomId),
  employeeId: text("employee_id").notNull().references(() => employees.id),
  projectId: text("project_id"),
  siteId: text("site_id").references(() => sites.id),
  workOrderId: text("work_order_id").references(() => workOrders.id),
  eventType: attendanceEventType("event_type").notNull(),
  eventAt: timestamp("event_at", { withTimezone: true }).notNull().defaultNow(),
  source: attendanceSource("source").notNull().default("mobile"),
  latitude: numeric("latitude", { precision: 10, scale: 7 }),
  longitude: numeric("longitude", { precision: 10, scale: 7 }),
  locationAccuracyMeters: numeric("location_accuracy_meters", { precision: 10, scale: 2 }),
  geofenceDistanceMeters: numeric("geofence_distance_meters", { precision: 10, scale: 2 }),
  isWithinGeofence: boolean("is_within_geofence"),
  deviceId: text("device_id"),
  ipAddress: text("ip_address"),
  photoDocumentId: text("photo_document_id"),
  notes: text("notes"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  employeeEventAtIdx: index("attendance_events_employee_event_at_idx").on(table.employeeId, table.eventAt),
  siteIdx: index("attendance_events_site_idx").on(table.siteId),
  workOrderIdx: index("attendance_events_work_order_idx").on(table.workOrderId),
}));

export const timesheets = pgTable("timesheets", {
  id: text("id").primaryKey().$defaultFn(randomId),
  employeeId: text("employee_id").notNull().references(() => employees.id),
  periodStart: date("period_start").notNull(),
  periodEnd: date("period_end").notNull(),
  status: approvalStatus("status").notNull().default("draft"),
  regularHours: numeric("regular_hours", { precision: 10, scale: 2 }).notNull().default("0"),
  overtimeHours: numeric("overtime_hours", { precision: 10, scale: 2 }).notNull().default("0"),
  approvedAt: timestamp("approved_at", { withTimezone: true }),
  approvedByUserId: text("approved_by_user_id"),
  notes: text("notes"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  employeePeriodUnique: uniqueIndex("timesheets_employee_period_unique").on(table.employeeId, table.periodStart, table.periodEnd),
  employeeIdx: index("timesheets_employee_idx").on(table.employeeId),
  statusIdx: index("timesheets_status_idx").on(table.status),
}));

export const timesheetEntries = pgTable("timesheet_entries", {
  id: text("id").primaryKey().$defaultFn(randomId),
  timesheetId: text("timesheet_id").notNull().references(() => timesheets.id),
  employeeId: text("employee_id").notNull().references(() => employees.id),
  projectId: text("project_id"),
  siteId: text("site_id").references(() => sites.id),
  workOrderId: text("work_order_id").references(() => workOrders.id),
  entryDate: date("entry_date").notNull(),
  regularHours: numeric("regular_hours", { precision: 10, scale: 2 }).notNull().default("0"),
  overtimeHours: numeric("overtime_hours", { precision: 10, scale: 2 }).notNull().default("0"),
  laborRate: numeric("labor_rate", { precision: 14, scale: 2 }).notNull().default("0"),
  overtimeRate: numeric("overtime_rate", { precision: 14, scale: 2 }).notNull().default("0"),
  laborCost: numeric("labor_cost", { precision: 14, scale: 2 }).notNull().default("0"),
  notes: text("notes"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  timesheetIdx: index("timesheet_entries_timesheet_idx").on(table.timesheetId),
  employeeDateIdx: index("timesheet_entries_employee_date_idx").on(table.employeeId, table.entryDate),
  projectSiteIdx: index("timesheet_entries_project_site_idx").on(table.projectId, table.siteId),
}));

export const projectCosts = pgTable("project_costs", {
  id: text("id").primaryKey().$defaultFn(randomId),
  projectId: text("project_id").notNull(),
  siteId: text("site_id").references(() => sites.id),
  workOrderId: text("work_order_id").references(() => workOrders.id),
  costType: projectCostType("cost_type").notNull(),
  sourceType: text("source_type"),
  sourceId: text("source_id"),
  description: text("description").notNull(),
  quantity: numeric("quantity", { precision: 14, scale: 3 }).notNull().default("1"),
  unitCost: numeric("unit_cost", { precision: 14, scale: 2 }).notNull().default("0"),
  totalCost: numeric("total_cost", { precision: 14, scale: 2 }).notNull().default("0"),
  incurredOn: date("incurred_on").notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  projectIdx: index("project_costs_project_idx").on(table.projectId),
  siteIdx: index("project_costs_site_idx").on(table.siteId),
  workOrderIdx: index("project_costs_work_order_idx").on(table.workOrderId),
  costTypeIdx: index("project_costs_type_idx").on(table.costType),
}));

export const payrollRuns = pgTable("payroll_runs", {
  id: text("id").primaryKey().$defaultFn(randomId),
  payrollNo: text("payroll_no").notNull(),
  periodStart: date("period_start").notNull(),
  periodEnd: date("period_end").notNull(),
  status: payrollStatus("status").notNull().default("draft"),
  grossPayTotal: numeric("gross_pay_total", { precision: 14, scale: 2 }).notNull().default("0"),
  deductionsTotal: numeric("deductions_total", { precision: 14, scale: 2 }).notNull().default("0"),
  advancesTotal: numeric("advances_total", { precision: 14, scale: 2 }).notNull().default("0"),
  netPayTotal: numeric("net_pay_total", { precision: 14, scale: 2 }).notNull().default("0"),
  approvedAt: timestamp("approved_at", { withTimezone: true }),
  approvedByUserId: text("approved_by_user_id"),
  paidAt: timestamp("paid_at", { withTimezone: true }),
  notes: text("notes"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  payrollNoUnique: uniqueIndex("payroll_runs_no_unique").on(table.payrollNo),
  periodIdx: index("payroll_runs_period_idx").on(table.periodStart, table.periodEnd),
  statusIdx: index("payroll_runs_status_idx").on(table.status),
}));

export const payrollEntries = pgTable("payroll_entries", {
  id: text("id").primaryKey().$defaultFn(randomId),
  payrollRunId: text("payroll_run_id").notNull().references(() => payrollRuns.id),
  employeeId: text("employee_id").notNull().references(() => employees.id),
  timesheetId: text("timesheet_id").references(() => timesheets.id),
  regularHours: numeric("regular_hours", { precision: 10, scale: 2 }).notNull().default("0"),
  overtimeHours: numeric("overtime_hours", { precision: 10, scale: 2 }).notNull().default("0"),
  basicPay: numeric("basic_pay", { precision: 14, scale: 2 }).notNull().default("0"),
  overtimePay: numeric("overtime_pay", { precision: 14, scale: 2 }).notNull().default("0"),
  allowances: numeric("allowances", { precision: 14, scale: 2 }).notNull().default("0"),
  deductions: numeric("deductions", { precision: 14, scale: 2 }).notNull().default("0"),
  advancesRecovered: numeric("advances_recovered", { precision: 14, scale: 2 }).notNull().default("0"),
  grossPay: numeric("gross_pay", { precision: 14, scale: 2 }).notNull().default("0"),
  netPay: numeric("net_pay", { precision: 14, scale: 2 }).notNull().default("0"),
  payslipDocumentId: text("payslip_document_id"),
  notes: text("notes"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  runEmployeeUnique: uniqueIndex("payroll_entries_run_employee_unique").on(table.payrollRunId, table.employeeId),
  employeeIdx: index("payroll_entries_employee_idx").on(table.employeeId),
}));

export const employeeAdvances = pgTable("employee_advances", {
  id: text("id").primaryKey().$defaultFn(randomId),
  advanceNo: text("advance_no").notNull(),
  employeeId: text("employee_id").notNull().references(() => employees.id),
  requestedAmount: numeric("requested_amount", { precision: 14, scale: 2 }).notNull(),
  approvedAmount: numeric("approved_amount", { precision: 14, scale: 2 }),
  paidAmount: numeric("paid_amount", { precision: 14, scale: 2 }).notNull().default("0"),
  recoveredAmount: numeric("recovered_amount", { precision: 14, scale: 2 }).notNull().default("0"),
  balanceAmount: numeric("balance_amount", { precision: 14, scale: 2 }).notNull().default("0"),
  reason: text("reason").notNull(),
  status: approvalStatus("status").notNull().default("draft"),
  requestedAt: timestamp("requested_at", { withTimezone: true }).notNull().defaultNow(),
  approvedAt: timestamp("approved_at", { withTimezone: true }),
  approvedByUserId: text("approved_by_user_id"),
  paidAt: timestamp("paid_at", { withTimezone: true }),
  paymentReference: text("payment_reference"),
  repaymentPlanJson: text("repayment_plan_json"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  advanceNoUnique: uniqueIndex("employee_advances_no_unique").on(table.advanceNo),
  employeeIdx: index("employee_advances_employee_idx").on(table.employeeId),
  statusIdx: index("employee_advances_status_idx").on(table.status),
}));

export const leaveRequests = pgTable("leave_requests", {
  id: text("id").primaryKey().$defaultFn(randomId),
  leaveNo: text("leave_no").notNull(),
  employeeId: text("employee_id").notNull().references(() => employees.id),
  leaveType: leaveType("leave_type").notNull(),
  status: approvalStatus("status").notNull().default("draft"),
  startDate: date("start_date").notNull(),
  endDate: date("end_date").notNull(),
  totalDays: numeric("total_days", { precision: 10, scale: 2 }).notNull(),
  reason: text("reason"),
  handoverNotes: text("handover_notes"),
  emergencyContactDuringLeave: text("emergency_contact_during_leave"),
  submittedAt: timestamp("submitted_at", { withTimezone: true }),
  approvedAt: timestamp("approved_at", { withTimezone: true }),
  approvedByUserId: text("approved_by_user_id"),
  rejectionReason: text("rejection_reason"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  leaveNoUnique: uniqueIndex("leave_requests_no_unique").on(table.leaveNo),
  employeeIdx: index("leave_requests_employee_idx").on(table.employeeId),
  statusIdx: index("leave_requests_status_idx").on(table.status),
}));

export const employeesRelations = relations(employees, ({ many }) => ({
  attendanceEvents: many(attendanceEvents),
  workOrderAssignments: many(workOrderAssignments),
  timesheets: many(timesheets),
  payrollEntries: many(payrollEntries),
  advances: many(employeeAdvances),
  leaveRequests: many(leaveRequests),
}));

export const sitesRelations = relations(sites, ({ many }) => ({
  workOrders: many(workOrders),
  attendanceEvents: many(attendanceEvents),
  projectCosts: many(projectCosts),
}));

export const workOrdersRelations = relations(workOrders, ({ one, many }) => ({
  site: one(sites, { fields: [workOrders.siteId], references: [sites.id] }),
  assignments: many(workOrderAssignments),
  attendanceEvents: many(attendanceEvents),
  projectCosts: many(projectCosts),
}));

export const workOrderAssignmentsRelations = relations(workOrderAssignments, ({ one }) => ({
  workOrder: one(workOrders, { fields: [workOrderAssignments.workOrderId], references: [workOrders.id] }),
  employee: one(employees, { fields: [workOrderAssignments.employeeId], references: [employees.id] }),
}));

export const attendanceEventsRelations = relations(attendanceEvents, ({ one }) => ({
  employee: one(employees, { fields: [attendanceEvents.employeeId], references: [employees.id] }),
  site: one(sites, { fields: [attendanceEvents.siteId], references: [sites.id] }),
  workOrder: one(workOrders, { fields: [attendanceEvents.workOrderId], references: [workOrders.id] }),
}));

export const timesheetsRelations = relations(timesheets, ({ one, many }) => ({
  employee: one(employees, { fields: [timesheets.employeeId], references: [employees.id] }),
  entries: many(timesheetEntries),
  payrollEntries: many(payrollEntries),
}));

export const timesheetEntriesRelations = relations(timesheetEntries, ({ one }) => ({
  timesheet: one(timesheets, { fields: [timesheetEntries.timesheetId], references: [timesheets.id] }),
  employee: one(employees, { fields: [timesheetEntries.employeeId], references: [employees.id] }),
  site: one(sites, { fields: [timesheetEntries.siteId], references: [sites.id] }),
  workOrder: one(workOrders, { fields: [timesheetEntries.workOrderId], references: [workOrders.id] }),
}));

export const projectCostsRelations = relations(projectCosts, ({ one }) => ({
  site: one(sites, { fields: [projectCosts.siteId], references: [sites.id] }),
  workOrder: one(workOrders, { fields: [projectCosts.workOrderId], references: [workOrders.id] }),
}));

export const payrollRunsRelations = relations(payrollRuns, ({ many }) => ({
  entries: many(payrollEntries),
}));

export const payrollEntriesRelations = relations(payrollEntries, ({ one }) => ({
  payrollRun: one(payrollRuns, { fields: [payrollEntries.payrollRunId], references: [payrollRuns.id] }),
  employee: one(employees, { fields: [payrollEntries.employeeId], references: [employees.id] }),
  timesheet: one(timesheets, { fields: [payrollEntries.timesheetId], references: [timesheets.id] }),
}));

export const employeeAdvancesRelations = relations(employeeAdvances, ({ one }) => ({
  employee: one(employees, { fields: [employeeAdvances.employeeId], references: [employees.id] }),
}));

export const leaveRequestsRelations = relations(leaveRequests, ({ one }) => ({
  employee: one(employees, { fields: [leaveRequests.employeeId], references: [employees.id] }),
}));
