# Replit PostgreSQL + Drizzle Client Portal Analysis

## Decision summary

The new directive is internally consistent and should supersede the earlier Prisma + Supabase implementation direction for the client portal.

Build target:

```text
Runtime: Replit
Database: Replit PostgreSQL
ORM: Drizzle
Auth model: Separate staff users and client users
Tenant model: Single-company AUM deployment; no tenant_id machinery
Supabase: Not used
Prisma: Not used
```

## Correct architectural interpretation

The attached Prisma/Supabase-oriented files should be treated as functional specifications, not as code to copy directly.

Keep the product behavior:

- Client-facing login
- Client dashboard
- Ticket tracking
- SOP progress visibility
- Compliance status visibility
- AI status/update visibility
- Document upload
- Read-only exposure of staff-side Service Ticket progress

Adapt the infrastructure:

- Replace Prisma schema/migrations with Drizzle schema and migrations.
- Replace Supabase Auth with `client_users` authentication.
- Replace Supabase RLS with API-level authorization middleware.
- Remove `tenant_id` assumptions because AUM is a single company CRM.
- Keep staff and client identities fully separated.

## Key recommendation

Do not merge client accounts into the staff `users` table.

Use two separate identity tables:

```text
staff_users
client_users
```

This is safer because external clients have a narrower security boundary and should never accidentally inherit staff roles, staff middleware, or admin permissions.

## Proposed database tables

### client_users

```ts
clientUsers = pgTable("client_users", {
  id: uuid("id").primaryKey().defaultRandom(),
  clientId: uuid("client_id").notNull().references(() => clients.id, { onDelete: "cascade" }),
  email: text("email").notNull().unique(),
  passwordHash: text("password_hash").notNull(),
  name: text("name"),
  phone: text("phone"),
  status: text("status").notNull().default("active"),
  lastLoginAt: timestamp("last_login_at"),
  createdAt: timestamp("created_at").notNull().defaultNow(),
  updatedAt: timestamp("updated_at").notNull().defaultNow()
});
```

### client_sessions / refresh tokens

```ts
clientSessions = pgTable("client_sessions", {
  id: uuid("id").primaryKey().defaultRandom(),
  clientUserId: uuid("client_user_id").notNull().references(() => clientUsers.id, { onDelete: "cascade" }),
  tokenHash: text("token_hash").notNull(),
  expiresAt: timestamp("expires_at").notNull(),
  revokedAt: timestamp("revoked_at"),
  ipAddress: text("ip_address"),
  userAgent: text("user_agent"),
  createdAt: timestamp("created_at").notNull().defaultNow()
});
```

### client_documents

```ts
clientDocuments = pgTable("client_documents", {
  id: uuid("id").primaryKey().defaultRandom(),
  clientId: uuid("client_id").notNull().references(() => clients.id, { onDelete: "cascade" }),
  uploadedByClientUserId: uuid("uploaded_by_client_user_id").references(() => clientUsers.id),
  relatedType: text("related_type"),
  relatedId: uuid("related_id"),
  documentType: text("document_type"),
  fileName: text("file_name").notNull(),
  fileUrl: text("file_url").notNull(),
  mimeType: text("mime_type"),
  sizeBytes: integer("size_bytes"),
  status: text("status").notNull().default("uploaded"),
  createdAt: timestamp("created_at").notNull().defaultNow()
});
```

### client_portal_activity

```ts
clientPortalActivity = pgTable("client_portal_activity", {
  id: uuid("id").primaryKey().defaultRandom(),
  clientUserId: uuid("client_user_id").references(() => clientUsers.id),
  clientId: uuid("client_id").references(() => clients.id),
  action: text("action").notNull(),
  entityType: text("entity_type"),
  entityId: uuid("entity_id"),
  metadata: jsonb("metadata"),
  ipAddress: text("ip_address"),
  userAgent: text("user_agent"),
  createdAt: timestamp("created_at").notNull().defaultNow()
});
```

## API boundary

Create a dedicated client portal route tree:

```text
/api/client/auth/login
/api/client/auth/logout
/api/client/auth/me
/api/client/dashboard
/api/client/tickets
/api/client/tickets/:id
/api/client/tickets/:id/comments
/api/client/tickets/:id/documents
/api/client/documents
/api/client/profile
```

Do not reuse staff auth middleware.

Use:

```text
requireClientAuth
```

not:

```text
requireStaffAuth
requireRole
```

## Client authorization rule

Every client portal query must be scoped by the authenticated client's `clientId`.

Example:

```ts
where(and(
  eq(serviceTickets.clientId, req.clientUser.clientId),
  eq(serviceTickets.id, ticketId)
));
```

Never trust IDs from the URL without also checking ownership.

## SOP progress exposure

Client portal should be read-only for SOP progress.

Expose:

- SOP title
- SOP total steps
- completed steps
- completion percentage
- current stage
- technician/admin public updates
- last updated timestamp

Do not expose:

- internal technician notes marked private
- AI prompts
- raw model output used internally
- staff-only compliance/audit data
- assignment logic
- internal escalation notes

## AI updates exposure

AI assistant output should be transformed into client-safe updates.

Recommended data shape:

```ts
{
  status: "in_progress",
  publicSummary: "Technician is checking network connectivity and device power status.",
  nextStep: "Awaiting site verification.",
  updatedAt: "..."
}
```

Avoid exposing raw AI reasoning, model prompts, internal confidence scores, or debugging details.

## Compliance status exposure

Expose summary only:

- required documents
- received documents
- pending documents
- approved/rejected status
- due dates

Keep internal audit notes private.

## Document upload design

If using Replit filesystem, only use it for early MVP testing. For production, prefer object storage such as S3, Cloudflare R2, UploadThing, or another file storage provider.

Minimum requirements:

- Validate file type
- Validate file size
- Generate server-side file names
- Never trust client-provided paths
- Store metadata in `client_documents`
- Link documents to ticket/compliance/project when applicable

## What to remove from earlier Supabase/Prisma assumptions

Remove or ignore:

- Supabase Auth code
- Supabase client-side direct table access
- Supabase RLS policy assumptions
- `tenant_id` on all tables unless later turning this into a multi-company SaaS
- Prisma migrations and Prisma Client usage
- `customers.user_id = auth.uid()` linkage pattern

Replace with:

- Drizzle schema
- Express API authorization
- `client_users.client_id`
- JWT/session middleware for client portal
- API-scoped data access only

## Migration risk

The biggest risk is accidentally mixing prior Supabase/Prisma artifacts into the Replit/Drizzle build.

Codex should be explicitly instructed:

```text
Do not import Prisma.
Do not use Supabase Auth.
Do not use Supabase RLS.
Do not add tenant_id unless explicitly requested later.
Do not merge client_users into staff users.
Use Drizzle migrations only.
```

## Acceptance criteria

Implementation is correct when:

1. Staff and client accounts are separate.
2. Client login only authenticates against `client_users`.
3. Client portal API always scopes records by `client_users.client_id`.
4. Clients can view only their own tickets, SOP progress, compliance status, AI-safe updates, and documents.
5. Clients cannot access staff routes or staff JWTs.
6. Clients cannot mutate SOP steps, internal ticket assignments, internal AI data, or staff notes.
7. Document uploads are validated and stored with metadata.
8. No Prisma, Supabase Auth, Supabase RLS, or tenant-wide SaaS assumptions remain in this implementation path.
