# Supabase PostgreSQL Migration Runbook

This project currently uses Replit PostgreSQL + Drizzle ORM.

Do **not** add Prisma.
Do **not** rewrite the schema.
Do **not** move to Supabase Auth during this database-host migration.

## Current connection points

Runtime DB connection:

```ts
// lib/db/src/index.ts
export const pool = new Pool({ connectionString: process.env.DATABASE_URL });
export const db = drizzle(pool, { schema });
```

Drizzle Kit schema push:

```ts
// lib/db/drizzle.config.ts
dbCredentials: {
  url: process.env.DATABASE_URL,
}
```

Data migration script:

```ts
// scripts/src/migrate-to-supabase.ts
const SOURCE_URL = process.env.DATABASE_URL;
const TARGET_URL = process.env.SUPABASE_DATABASE_URL;
```

## Required Replit Secrets

Keep both secrets during migration:

```text
DATABASE_URL=<current Replit PostgreSQL URL>
SUPABASE_DATABASE_URL=<Supabase PostgreSQL URI>
```

Only after migration verification should `DATABASE_URL` be changed permanently to the Supabase PostgreSQL URI.

## Step 1: Back up current Replit database

```bash
pg_dump "$DATABASE_URL" > replit_backup_$(date +%Y%m%d_%H%M%S).sql
```

## Step 2: Push Drizzle schema to Supabase

Run this as a temporary command override. Do not permanently change `DATABASE_URL` yet.

```bash
DATABASE_URL="$SUPABASE_DATABASE_URL" pnpm --filter @workspace/db run push
```

## Step 3: Migrate data from Replit PostgreSQL to Supabase PostgreSQL

```bash
pnpm --filter @workspace/scripts run migrate-to-supabase
```

Expected behavior:

- `DATABASE_URL` remains the Replit source database.
- `SUPABASE_DATABASE_URL` is the Supabase target database.
- The migration script copies data table-by-table.

## Step 4: Verify data

Compare row counts between source and target for core tables:

```text
tenants
users
clients
leads
quotations
quotation_items
projects
technician_assignments
job_updates
material_requirements
invoices
payments
amc_contracts
sop_templates
sop_template_steps
job_sops
job_sop_steps
service_tickets
inventory_items
workflows
```

If counts differ, do not cut over.

## Step 5: App smoke test against Supabase

Temporarily run the app with:

```bash
DATABASE_URL="$SUPABASE_DATABASE_URL" pnpm dev
```

Test:

- Login
- Dashboard
- Clients
- Leads
- Quotations
- Projects
- SOPs
- Tickets
- Inventory
- Invoices
- Users/settings

## Step 6: Permanent cutover

Only after successful verification:

```text
DATABASE_URL=<same value as SUPABASE_DATABASE_URL>
```

Keep `SUPABASE_DATABASE_URL` as a backup/explicit migration target.

## Rollback

If cutover fails:

1. Change `DATABASE_URL` back to the original Replit PostgreSQL URL.
2. Restart the Replit app.
3. Investigate migration logs and schema differences.

## Important rule

This migration moves database hosting only:

```text
Replit PostgreSQL -> Supabase PostgreSQL
```

It does not change:

- ORM: still Drizzle
- Auth: still current app auth
- Runtime connection var: still DATABASE_URL
- Schema source of truth: still lib/db/src/schema/*.ts
