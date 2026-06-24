import { pgTable, text, timestamp, jsonb, integer, pgEnum } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod/v4";

export const notificationChannelEnum = pgEnum("notification_channel", [
  "EMAIL",
  "WHATSAPP",
  "SYSTEM",
]);

// Delivery lifecycle of a single notification row. PENDING rows form a
// transactional outbox: they are enqueued in the same transaction as the
// business/automation event, then dispatched and retried by a sweep.
export const notificationStatusEnum = pgEnum("notification_status", [
  "PENDING",
  "SENT",
  "SKIPPED",
  "FAILED",
]);

// Autonomous business-event notification log. Every business event can be
// recorded here. EMAIL/WHATSAPP rows may be queued as PENDING and dispatched
// by a background sweep, while SYSTEM rows can be recorded immediately.
export const notificationsTable = pgTable("notifications", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  eventType: text("event_type").notNull(),
  channel: notificationChannelEnum("channel").notNull().default("SYSTEM"),
  status: notificationStatusEnum("status").notNull().default("SENT"),
  title: text("title").notNull(),
  body: text("body").notNull(),
  entityType: text("entity_type"),
  entityId: text("entity_id"),
  recipient: text("recipient"),
  metadata: jsonb("metadata"),
  attempts: integer("attempts").notNull().default(0),
  nextAttemptAt: timestamp("next_attempt_at", { withTimezone: true }),
  lastError: text("last_error"),
  isRead: text("is_read").notNull().default("false"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const insertNotificationSchema = createInsertSchema(notificationsTable).omit({
  id: true,
  createdAt: true,
});

export type InsertNotification = z.infer<typeof insertNotificationSchema>;
export type Notification = typeof notificationsTable.$inferSelect;

// Key/value application + company settings, editable by executives/admins.
export const appSettingsTable = pgTable("app_settings", {
  key: text("key").primaryKey(),
  value: text("value").notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow().$onUpdate(() => new Date()),
});

export const insertAppSettingSchema = createInsertSchema(appSettingsTable).omit({
  updatedAt: true,
});

export type InsertAppSetting = z.infer<typeof insertAppSettingSchema>;
export type AppSetting = typeof appSettingsTable.$inferSelect;
