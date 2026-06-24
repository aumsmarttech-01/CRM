import { pgTable, text, timestamp, numeric, integer, pgEnum } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod/v4";

export const quotationStatusEnum = pgEnum("quotation_status", [
  "DRAFT",
  "PENDING_APPROVAL",
  "APPROVED",
  "SENT",
  "ACCEPTED",
  "REJECTED",
  "EXPIRED",
]);

export const quotationsTable = pgTable("quotations", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  quoteNumber: text("quote_number").notNull().unique(),
  clientId: text("client_id").notNull(),
  leadId: text("lead_id"),
  projectName: text("project_name").notNull(),
  scopeOfSupply: text("scope_of_supply").notNull(),
  subtotal: numeric("subtotal", { precision: 12, scale: 2 }).notNull().default("0"),
  vatAmount: numeric("vat_amount", { precision: 12, scale: 2 }).notNull().default("0"),
  grandTotal: numeric("grand_total", { precision: 12, scale: 2 }).notNull().default("0"),
  paymentTerms: text("payment_terms").notNull().default("70% Deposit Upon Order Confirmation\n30% Upon Completion"),
  projectDuration: text("project_duration"),
  warrantyPeriod: text("warranty_period"),
  status: quotationStatusEnum("status").notNull().default("DRAFT"),
  preparedBy: text("prepared_by"),
  approvedBy: text("approved_by"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow().$onUpdate(() => new Date()),
});

export const quotationItemsTable = pgTable("quotation_items", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  quotationId: text("quotation_id").notNull(),
  description: text("description").notNull(),
  quantity: integer("quantity").notNull(),
  unitRate: numeric("unit_rate", { precision: 12, scale: 2 }).notNull(),
  vatAmount: numeric("vat_amount", { precision: 12, scale: 2 }).notNull(),
  totalAmount: numeric("total_amount", { precision: 12, scale: 2 }).notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const insertQuotationSchema = createInsertSchema(quotationsTable).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export const insertQuotationItemSchema = createInsertSchema(quotationItemsTable).omit({
  id: true,
  createdAt: true,
});

export type InsertQuotation = z.infer<typeof insertQuotationSchema>;
export type InsertQuotationItem = z.infer<typeof insertQuotationItemSchema>;
export type Quotation = typeof quotationsTable.$inferSelect;
export type QuotationItem = typeof quotationItemsTable.$inferSelect;
