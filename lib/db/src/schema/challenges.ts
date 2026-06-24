import { pgTable, text, timestamp, pgEnum } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod/v4";

export const challengeSeverityEnum = pgEnum("challenge_severity", [
  "LOW",
  "MEDIUM",
  "HIGH",
  "CRITICAL",
]);

export const challengeStatusEnum = pgEnum("challenge_status", [
  "OPEN",
  "IN_PROGRESS",
  "RESOLVED",
  "ESCALATED",
  "CLOSED",
]);

export const challengesTable = pgTable("challenges", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  projectId: text("project_id"),
  clientId: text("client_id"),
  reportedBy: text("reported_by").notNull(),
  title: text("title").notNull(),
  description: text("description").notNull(),
  severity: challengeSeverityEnum("severity").notNull().default("MEDIUM"),
  status: challengeStatusEnum("status").notNull().default("OPEN"),
  assignedTo: text("assigned_to"),
  resolution: text("resolution"),
  resolvedAt: timestamp("resolved_at", { withTimezone: true }),
  resolvedBy: text("resolved_by"),
  photoUrl: text("photo_url"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow().$onUpdate(() => new Date()),
});

export const insertChallengeSchema = createInsertSchema(challengesTable).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export type InsertChallenge = z.infer<typeof insertChallengeSchema>;
export type Challenge = typeof challengesTable.$inferSelect;
