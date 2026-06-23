import { relations } from "drizzle-orm";
import {
  boolean,
  index,
  integer,
  jsonb,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
  uuid
} from "drizzle-orm/pg-core";

// Client Portal identity is intentionally separate from staff users.
// Do not merge this table into staff users.
// Do not add tenant_id. This CRM is a single-company AUM deployment.

export const clientUsers = pgTable(
  "client_users",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    clientId: uuid("client_id").notNull(),
    email: text("email").notNull(),
    passwordHash: text("password_hash").notNull(),
    name: text("name"),
    phone: text("phone"),
    status: text("status").notNull().default("active"),
    mustChangePassword: boolean("must_change_password").notNull().default(false),
    lastLoginAt: timestamp("last_login_at", { withTimezone: true }),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow()
  },
  (table) => ({
    emailUnique: uniqueIndex("client_users_email_unique").on(table.email),
    clientIdIdx: index("client_users_client_id_idx").on(table.clientId),
    statusIdx: index("client_users_status_idx").on(table.status)
  })
);

export const clientSessions = pgTable(
  "client_sessions",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    clientUserId: uuid("client_user_id").notNull().references(() => clientUsers.id, { onDelete: "cascade" }),
    tokenHash: text("token_hash").notNull(),
    expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
    revokedAt: timestamp("revoked_at", { withTimezone: true }),
    ipAddress: text("ip_address"),
    userAgent: text("user_agent"),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow()
  },
  (table) => ({
    clientUserIdIdx: index("client_sessions_client_user_id_idx").on(table.clientUserId),
    tokenHashIdx: index("client_sessions_token_hash_idx").on(table.tokenHash),
    expiresAtIdx: index("client_sessions_expires_at_idx").on(table.expiresAt)
  })
);

export const clientDocuments = pgTable(
  "client_documents",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    clientId: uuid("client_id").notNull(),
    uploadedByClientUserId: uuid("uploaded_by_client_user_id").references(() => clientUsers.id, { onDelete: "set null" }),
    relatedType: text("related_type"),
    relatedId: uuid("related_id"),
    documentType: text("document_type"),
    fileName: text("file_name").notNull(),
    originalFileName: text("original_file_name"),
    filePath: text("file_path").notNull(),
    fileUrl: text("file_url"),
    mimeType: text("mime_type"),
    sizeBytes: integer("size_bytes"),
    status: text("status").notNull().default("uploaded"),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow()
  },
  (table) => ({
    clientIdIdx: index("client_documents_client_id_idx").on(table.clientId),
    relatedIdx: index("client_documents_related_idx").on(table.relatedType, table.relatedId),
    uploadedByIdx: index("client_documents_uploaded_by_idx").on(table.uploadedByClientUserId)
  })
);

export const clientPortalActivity = pgTable(
  "client_portal_activity",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    clientUserId: uuid("client_user_id").references(() => clientUsers.id, { onDelete: "set null" }),
    clientId: uuid("client_id"),
    action: text("action").notNull(),
    entityType: text("entity_type"),
    entityId: uuid("entity_id"),
    metadata: jsonb("metadata"),
    ipAddress: text("ip_address"),
    userAgent: text("user_agent"),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow()
  },
  (table) => ({
    clientIdIdx: index("client_portal_activity_client_id_idx").on(table.clientId),
    clientUserIdIdx: index("client_portal_activity_client_user_id_idx").on(table.clientUserId),
    actionIdx: index("client_portal_activity_action_idx").on(table.action)
  })
);

export const clientUsersRelations = relations(clientUsers, ({ many }) => ({
  sessions: many(clientSessions),
  documents: many(clientDocuments),
  activity: many(clientPortalActivity)
}));

export const clientSessionsRelations = relations(clientSessions, ({ one }) => ({
  clientUser: one(clientUsers, {
    fields: [clientSessions.clientUserId],
    references: [clientUsers.id]
  })
}));
