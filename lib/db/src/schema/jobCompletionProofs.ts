import { pgTable, text, timestamp, pgEnum } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod/v4";

export const proofStatusEnum = pgEnum("proof_status", [
  "PENDING_REVIEW",
  "APPROVED",
  "REJECTED",
]);

export const jobCompletionProofsTable = pgTable("job_completion_proofs", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  projectId: text("project_id").notNull(),
  technicianId: text("technician_id").notNull(),
  summary: text("summary").notNull(),
  photoUrls: text("photo_urls"),
  status: proofStatusEnum("status").notNull().default("PENDING_REVIEW"),
  submittedAt: timestamp("submitted_at", { withTimezone: true }).notNull().defaultNow(),
  reviewedAt: timestamp("reviewed_at", { withTimezone: true }),
  reviewedBy: text("reviewed_by"),
  reviewNotes: text("review_notes"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow().$onUpdate(() => new Date()),
});

export const insertProofSchema = createInsertSchema(jobCompletionProofsTable).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
  submittedAt: true,
  reviewedAt: true,
  reviewedBy: true,
  reviewNotes: true,
  status: true,
});

export type InsertProof = z.infer<typeof insertProofSchema>;
export type CompletionProof = typeof jobCompletionProofsTable.$inferSelect;
