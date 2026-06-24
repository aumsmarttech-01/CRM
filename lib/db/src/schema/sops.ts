import { pgTable, text, timestamp, pgEnum, integer, boolean } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod/v4";

export const sopStepStatusEnum = pgEnum("sop_step_status", [
  "PENDING",
  "IN_PROGRESS",
  "COMPLETED",
  "SKIPPED",
  "FAILED",
]);

export const sopTemplatesTable = pgTable("sop_templates", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  name: text("name").notNull(),
  category: text("category").notNull(),
  description: text("description"),
  isDefault: boolean("is_default").notNull().default(false),
  createdBy: text("created_by"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow().$onUpdate(() => new Date()),
});

export const sopTemplateStepsTable = pgTable("sop_template_steps", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  templateId: text("template_id").notNull(),
  stepNumber: integer("step_number").notNull(),
  title: text("title").notNull(),
  description: text("description"),
  isRequired: boolean("is_required").notNull().default(true),
  estimatedMinutes: integer("estimated_minutes"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const jobSopsTable = pgTable("job_sops", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  projectId: text("project_id").notNull(),
  templateId: text("template_id"),
  name: text("name").notNull(),
  completionRate: integer("completion_rate").notNull().default(0),
  complianceScore: integer("compliance_score").notNull().default(0),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow().$onUpdate(() => new Date()),
});

export const jobSopStepsTable = pgTable("job_sop_steps", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  jobSopId: text("job_sop_id").notNull(),
  stepNumber: integer("step_number").notNull(),
  title: text("title").notNull(),
  description: text("description"),
  isRequired: boolean("is_required").notNull().default(true),
  status: sopStepStatusEnum("status").notNull().default("PENDING"),
  completedBy: text("completed_by"),
  completedAt: timestamp("completed_at", { withTimezone: true }),
  evidenceNote: text("evidence_note"),
  photoUrl: text("photo_url"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

// Legacy/simple notification table kept for compatibility with existing SOP/job flows.
// The newer notifications table should be used as the long-term transactional outbox.
export const notificationLogsTable = pgTable("notification_logs", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  type: text("type").notNull(),
  channel: text("channel").notNull(),
  recipient: text("recipient").notNull(),
  subject: text("subject"),
  body: text("body"),
  status: text("status").notNull().default("PENDING"),
  sentAt: timestamp("sent_at", { withTimezone: true }),
  errorMessage: text("error_message"),
  referenceId: text("reference_id"),
  referenceType: text("reference_type"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const insertSopTemplateSchema = createInsertSchema(sopTemplatesTable).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export const insertSopTemplateStepSchema = createInsertSchema(sopTemplateStepsTable).omit({
  id: true,
  createdAt: true,
});

export const insertJobSopSchema = createInsertSchema(jobSopsTable).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export const insertJobSopStepSchema = createInsertSchema(jobSopStepsTable).omit({
  id: true,
  createdAt: true,
});

export type InsertSopTemplate = z.infer<typeof insertSopTemplateSchema>;
export type InsertSopTemplateStep = z.infer<typeof insertSopTemplateStepSchema>;
export type InsertJobSop = z.infer<typeof insertJobSopSchema>;
export type InsertJobSopStep = z.infer<typeof insertJobSopStepSchema>;

export type SopTemplate = typeof sopTemplatesTable.$inferSelect;
export type SopTemplateStep = typeof sopTemplateStepsTable.$inferSelect;
export type JobSop = typeof jobSopsTable.$inferSelect;
export type JobSopStep = typeof jobSopStepsTable.$inferSelect;
export type NotificationLog = typeof notificationLogsTable.$inferSelect;
