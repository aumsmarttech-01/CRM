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
  uuid,
} from "drizzle-orm/pg-core";

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

export const employees = pgTable("employees", {
  id: uuid("id").primaryKey().defaultRandom(),
  staffUserId: uuid("staff_user_id"),
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
}));

export const sites = pgTable("sites", {
  id: uuid("id").primaryKey().defaultRandom(),
  clientId: uuid("client_id"),
  projectId: uuid("project_id"),
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
});

export const workOrders = pgTable("work_orders", {
  id: uuid("id").primaryKey().defaultRandom(),
  workOrderNo: text("work_order_no").notNull(),
  clientId: uuid("client_id"),
  projectId: uuid("project_id"),
  siteId: uuid("site_id").references(() => sites.id),
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
});

export const attendanceEvents = pgTable("attendance_events", {
  id: uuid("id").primaryKey().defaultRandom(),
  employeeId: uuid("employee_id").notNull().references(() => employees.id),
  projectId: uuid("project_id"),
  siteId: uuid("site_id").references(() => sites.id),
  workOrderId: uuid("work_order_id").references(() => workOrders.id),
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
  photoDocumentId: uuid("photo_document_id"),
  notes: text("notes"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const projectCosts = pgTable("project_costs", {
  id: uuid("id").primaryKey().defaultRandom(),
  projectId: uuid("project_id").notNull(),
  siteId: uuid("site_id").references(() => sites.id),
  workOrderId: uuid("work_order_id").references(() => workOrders.id),
  costType: projectCostType("cost_type").notNull(),
  sourceType: text("source_type"),
  sourceId: uuid("source_id"),
  description: text("description").notNull(),
  quantity: numeric("quantity", { precision: 14, scale: 3 }).notNull().default("1"),
  unitCost: numeric("unit_cost", { precision: 14, scale: 2 }).notNull().default("0"),
  totalCost: numeric("total_cost", { precision: 14, scale: 2 }).notNull().default("0"),
  incurredOn: date("incurred_on").notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const employeesRelations = relations(employees, ({ many }) => ({
  attendanceEvents: many(attendanceEvents),
}));

export const sitesRelations = relations(sites, ({ many }) => ({
  workOrders: many(workOrders),
  attendanceEvents: many(attendanceEvents),
  projectCosts: many(projectCosts),
}));

export const workOrdersRelations = relations(workOrders, ({ one, many }) => ({
  site: one(sites, { fields: [workOrders.siteId], references: [sites.id] }),
  attendanceEvents: many(attendanceEvents),
  projectCosts: many(projectCosts),
}));

export const attendanceEventsRelations = relations(attendanceEvents, ({ one }) => ({
  employee: one(employees, { fields: [attendanceEvents.employeeId], references: [employees.id] }),
  site: one(sites, { fields: [attendanceEvents.siteId], references: [sites.id] }),
  workOrder: one(workOrders, { fields: [attendanceEvents.workOrderId], references: [workOrders.id] }),
}));

export const projectCostsRelations = relations(projectCosts, ({ one }) => ({
  site: one(sites, { fields: [projectCosts.siteId], references: [sites.id] }),
  workOrder: one(workOrders, { fields: [projectCosts.workOrderId], references: [workOrders.id] }),
}));
