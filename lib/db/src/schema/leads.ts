import { pgTable, text, timestamp, numeric, pgEnum } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod/v4";

export const leadStatusEnum = pgEnum("lead_status", [
  "NEW",
  "CONTACTED",
  "SITE_VISIT_SCHEDULED",
  "QUOTED",
  "WON",
  "LOST",
  "ON_HOLD",
]);

export const leadsTable = pgTable("leads", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  clientId: text("client_id").notNull(),
  leadSource: text("lead_source"),
  serviceCategory: text("service_category").notNull(),
  description: text("description"),
  estimatedBudget: numeric("estimated_budget", { precision: 12, scale: 2 }),
  status: leadStatusEnum("status").notNull().default("NEW"),
  assignedTo: text("assigned_to"),
  followUpDate: timestamp("follow_up_date", { withTimezone: true }),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow().$onUpdate(() => new Date()),
});

export const insertLeadSchema = createInsertSchema(leadsTable).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export type InsertLead = z.infer<typeof insertLeadSchema>;
export type Lead = typeof leadsTable.$inferSelect;
