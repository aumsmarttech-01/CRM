import { index, jsonb, pgTable, text, timestamp, integer } from "drizzle-orm/pg-core";

const randomId = () => crypto.randomUUID();

/**
 * Production audit trail for sensitive CRM/ERP actions.
 *
 * Tracks staff, client-portal, automation, and system mutations across connected
 * modules: projects, tickets, SOPs, compliance, attendance, payroll, inventory,
 * invoices, payments, notifications, and settings.
 */
export const auditLogsTable = pgTable("audit_logs", {
  id: text("id").primaryKey().$defaultFn(randomId),

  actorType: text("actor_type").notNull().default("staff"),
  actorUserId: text("actor_user_id"),
  actorEmail: text("actor_email"),

  action: text("action").notNull(),
  tableName: text("table_name").notNull(),
  recordId: text("record_id"),

  before: jsonb("before_data"),
  after: jsonb("after_data"),

  ipAddress: text("ip_address"),
  userAgent: text("user_agent"),
  requestId: text("request_id"),
  statusCode: integer("status_code"),

  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  tableRecordIdx: index("audit_logs_table_record_idx").on(table.tableName, table.recordId),
  actorIdx: index("audit_logs_actor_idx").on(table.actorType, table.actorUserId),
  actionIdx: index("audit_logs_action_idx").on(table.action),
  createdAtIdx: index("audit_logs_created_at_idx").on(table.createdAt),
}));

export type AuditLog = typeof auditLogsTable.$inferSelect;
export type InsertAuditLog = typeof auditLogsTable.$inferInsert;
