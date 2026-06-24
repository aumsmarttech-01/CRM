import { pgTable, text, timestamp, pgEnum } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod/v4";

export const followUpStatusEnum = pgEnum("follow_up_status", [
  "PENDING",
  "IN_PROGRESS",
  "DONE",
  "CANCELLED",
]);

export const followUpPriorityEnum = pgEnum("follow_up_priority", [
  "LOW",
  "MEDIUM",
  "HIGH",
  "URGENT",
]);

export const followUpsTable = pgTable("follow_ups", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  clientId: text("client_id"),
  leadId: text("lead_id"),
  projectId: text("project_id"),
  assignedTo: text("assigned_to").notNull(),
  dueDate: timestamp("due_date", { withTimezone: true }).notNull(),
  subject: text("subject").notNull(),
  notes: text("notes"),
  priority: followUpPriorityEnum("priority").notNull().default("MEDIUM"),
  status: followUpStatusEnum("status").notNull().default("PENDING"),
  completedAt: timestamp("completed_at", { withTimezone: true }),
  outcome: text("outcome"),
  createdBy: text("created_by"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow().$onUpdate(() => new Date()),
});

export const insertFollowUpSchema = createInsertSchema(followUpsTable).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export type InsertFollowUp = z.infer<typeof insertFollowUpSchema>;
export type FollowUp = typeof followUpsTable.$inferSelect;
