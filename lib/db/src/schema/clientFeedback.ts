import { pgTable, text, timestamp, pgEnum, integer } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod/v4";

export const feedbackTypeEnum = pgEnum("feedback_type", [
  "COMPLIMENT",
  "COMPLAINT",
  "SUGGESTION",
  "GENERAL",
]);

export const feedbackStatusEnum = pgEnum("feedback_status", [
  "OPEN",
  "IN_PROGRESS",
  "RESOLVED",
  "CLOSED",
]);

export const clientFeedbackTable = pgTable("client_feedback", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  clientId: text("client_id").notNull(),
  projectId: text("project_id"),
  invoiceId: text("invoice_id"),
  feedbackType: feedbackTypeEnum("feedback_type").notNull().default("GENERAL"),
  status: feedbackStatusEnum("status").notNull().default("OPEN"),
  rating: integer("rating"),
  subject: text("subject"),
  feedback: text("feedback").notNull(),
  response: text("response"),
  respondedBy: text("responded_by"),
  respondedAt: timestamp("responded_at", { withTimezone: true }),
  resolvedAt: timestamp("resolved_at", { withTimezone: true }),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow().$onUpdate(() => new Date()),
});

export const insertFeedbackSchema = createInsertSchema(clientFeedbackTable).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export type InsertFeedback = z.infer<typeof insertFeedbackSchema>;
export type ClientFeedback = typeof clientFeedbackTable.$inferSelect;
