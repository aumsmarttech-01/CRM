import { pgTable, text, timestamp, pgEnum } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod/v4";

export const complianceStatusEnum = pgEnum("compliance_status", [
  "PENDING",
  "IN_PROGRESS",
  "SUBMITTED",
  "APPROVED",
  "OVERDUE",
  "CANCELLED",
]);

export const compliancePriorityEnum = pgEnum("compliance_priority", [
  "LOW",
  "MEDIUM",
  "HIGH",
  "URGENT",
]);

export const complianceRecordsTable = pgTable("compliance_records", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  clientId: text("client_id").notNull(),
  projectId: text("project_id"),
  title: text("title").notNull(),
  requirementType: text("requirement_type"),
  referenceNumber: text("reference_number"),
  dueDate: timestamp("due_date", { withTimezone: true }).notNull(),
  status: complianceStatusEnum("status").notNull().default("PENDING"),
  priority: compliancePriorityEnum("priority").notNull().default("MEDIUM"),
  assignedTo: text("assigned_to"),
  submittedAt: timestamp("submitted_at", { withTimezone: true }),
  approvedAt: timestamp("approved_at", { withTimezone: true }),
  notes: text("notes"),
  createdBy: text("created_by"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow().$onUpdate(() => new Date()),
});

export const insertComplianceSchema = createInsertSchema(complianceRecordsTable).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export type InsertCompliance = z.infer<typeof insertComplianceSchema>;
export type ComplianceRecord = typeof complianceRecordsTable.$inferSelect;
