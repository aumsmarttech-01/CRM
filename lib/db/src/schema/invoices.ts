import { pgTable, text, timestamp, numeric, integer, pgEnum, unique } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod/v4";

export const invoiceStatusEnum = pgEnum("invoice_status", [
  "DRAFT",
  "SENT",
  "PARTIALLY_PAID",
  "PAID",
  "OVERDUE",
  "CANCELLED",
]);

// Sequential document numbering, for example AUM-INV-2026-0001.
// Keyed by docType + year.
export const documentCountersTable = pgTable("document_counters", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  docType: text("doc_type").notNull(),
  year: integer("year").notNull(),
  lastNumber: integer("last_number").notNull().default(0),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow().$onUpdate(() => new Date()),
}, (t) => [unique("doc_counter_type_year").on(t.docType, t.year)]);

export const invoicesTable = pgTable("invoices", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  invoiceNumber: text("invoice_number").notNull().unique(),
  clientId: text("client_id").notNull(),
  projectId: text("project_id"),
  quotationId: text("quotation_id"),
  subtotal: numeric("subtotal", { precision: 12, scale: 2 }).notNull().default("0"),
  vatAmount: numeric("vat_amount", { precision: 12, scale: 2 }).notNull().default("0"),
  grandTotal: numeric("grand_total", { precision: 12, scale: 2 }).notNull().default("0"),
  amountPaid: numeric("amount_paid", { precision: 12, scale: 2 }).notNull().default("0"),
  balanceDue: numeric("balance_due", { precision: 12, scale: 2 }).notNull().default("0"),
  status: invoiceStatusEnum("status").notNull().default("SENT"),
  notes: text("notes"),
  issueDate: timestamp("issue_date", { withTimezone: true }).notNull().defaultNow(),
  dueDate: timestamp("due_date", { withTimezone: true }),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow().$onUpdate(() => new Date()),
});

export const invoiceItemsTable = pgTable("invoice_items", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  invoiceId: text("invoice_id").notNull(),
  itemCode: text("item_code"),
  description: text("description").notNull(),
  quantity: integer("quantity").notNull().default(1),
  unitRate: numeric("unit_rate", { precision: 12, scale: 2 }).notNull(),
  vatAmount: numeric("vat_amount", { precision: 12, scale: 2 }).notNull().default("0"),
  totalAmount: numeric("total_amount", { precision: 12, scale: 2 }).notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const paymentsTable = pgTable("payments", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  invoiceId: text("invoice_id").notNull(),
  amount: numeric("amount", { precision: 12, scale: 2 }).notNull(),
  paymentMethod: text("payment_method").notNull(),
  paymentReference: text("payment_reference"),
  paymentDate: timestamp("payment_date", { withTimezone: true }).notNull().defaultNow(),
  receivedBy: text("received_by"),
  notes: text("notes"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const insertInvoiceSchema = createInsertSchema(invoicesTable).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export const insertInvoiceItemSchema = createInsertSchema(invoiceItemsTable).omit({
  id: true,
  createdAt: true,
});

export const insertPaymentSchema = createInsertSchema(paymentsTable).omit({
  id: true,
  createdAt: true,
});

export type InsertInvoice = z.infer<typeof insertInvoiceSchema>;
export type InsertInvoiceItem = z.infer<typeof insertInvoiceItemSchema>;
export type InsertPayment = z.infer<typeof insertPaymentSchema>;
export type Invoice = typeof invoicesTable.$inferSelect;
export type InvoiceItem = typeof invoiceItemsTable.$inferSelect;
export type Payment = typeof paymentsTable.$inferSelect;
