import { pgTable, text, timestamp, pgEnum, uniqueIndex } from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";

export const reviewTriggerEnum = pgEnum("review_trigger", [
  "PROJECT_COMPLETED",
  "INVOICE_PAID",
]);

/**
 * Audit/reference record of every Google review invitation sent to a client.
 * One row per entity/trigger. The presence of a row is also used to dedupe so
 * a client is never asked twice for the same completed project or paid invoice.
 * Partial unique indexes make that dedupe race-safe. No FK constraints because
 * the current repo convention uses text IDs without database-enforced FKs.
 */
export const reviewRequestsTable = pgTable(
  "review_requests",
  {
    id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
    clientId: text("client_id").notNull(),
    trigger: reviewTriggerEnum("trigger").notNull(),
    projectId: text("project_id"),
    invoiceId: text("invoice_id"),
    reviewUrl: text("review_url").notNull(),
    sentAt: timestamp("sent_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex("review_requests_trigger_project_uniq")
      .on(t.trigger, t.projectId)
      .where(sql`${t.projectId} is not null`),
    uniqueIndex("review_requests_trigger_invoice_uniq")
      .on(t.trigger, t.invoiceId)
      .where(sql`${t.invoiceId} is not null`),
  ],
);

export type ReviewRequest = typeof reviewRequestsTable.$inferSelect;
