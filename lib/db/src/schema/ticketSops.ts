import { pgTable, text, timestamp, integer, boolean } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod/v4";
import { sopStepStatusEnum } from "./sops";

// Discrete per-ticket SOP run. References a service ticket and optionally the
// reusable sop_templates library by id. No FKs by design: ticket SOP and
// project/job SOP lifecycles must stay separate.
export const ticketSopsTable = pgTable("ticket_sops", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  ticketId: text("ticket_id").notNull(),
  templateId: text("template_id"),
  name: text("name").notNull(),
  completionRate: integer("completion_rate").notNull().default(0),
  complianceScore: integer("compliance_score").notNull().default(0),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow().$onUpdate(() => new Date()),
});

export const ticketSopStepsTable = pgTable("ticket_sop_steps", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  ticketSopId: text("ticket_sop_id").notNull(),
  stepNumber: integer("step_number").notNull(),
  title: text("title").notNull(),
  description: text("description"),
  isRequired: boolean("is_required").notNull().default(true),
  status: sopStepStatusEnum("status").notNull().default("PENDING"),
  completedBy: text("completed_by"),
  completedAt: timestamp("completed_at", { withTimezone: true }),
  evidenceNote: text("evidence_note"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const ticketCommentsTable = pgTable("ticket_comments", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  ticketId: text("ticket_id").notNull(),
  authorId: text("author_id"),
  body: text("body").notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const insertTicketSopSchema = createInsertSchema(ticketSopsTable).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export const insertTicketSopStepSchema = createInsertSchema(ticketSopStepsTable).omit({
  id: true,
  createdAt: true,
});

export const insertTicketCommentSchema = createInsertSchema(ticketCommentsTable).omit({
  id: true,
  createdAt: true,
});

export type InsertTicketSop = z.infer<typeof insertTicketSopSchema>;
export type InsertTicketSopStep = z.infer<typeof insertTicketSopStepSchema>;
export type InsertTicketComment = z.infer<typeof insertTicketCommentSchema>;

export type TicketSop = typeof ticketSopsTable.$inferSelect;
export type TicketSopStep = typeof ticketSopStepsTable.$inferSelect;
export type TicketComment = typeof ticketCommentsTable.$inferSelect;
