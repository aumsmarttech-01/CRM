# Supabase MCP and Agent Skills Setup

This guide records how AUM CRM should configure Supabase MCP and optional Supabase Agent Skills for development support.

## Purpose

Supabase MCP and Agent Skills are development helpers. They are useful for schema inspection, migration support, SQL guidance, and more accurate AI-assisted Supabase work.

They do not replace the application backend, Drizzle schema, Express API, RBAC, or migration process.

## Recommended Use in This Project

Use Supabase MCP/Agent Skills for:

- Inspecting Supabase database schema.
- Checking migrations.
- Helping generate SQL safely.
- Reviewing database policies.
- Debugging Supabase connection and schema issues.

Do not use them to:

- Store secrets in code.
- Let the frontend connect directly to privileged database operations.
- Bypass the Express service layer.
- Replace Drizzle as the schema source of truth.

## Step 1: Configure MCP Client

Use the Supabase one-click MCP setup where available:

```text
Add to ChatGPT
```

After adding, verify that ChatGPT can access the Supabase MCP connector. The connector should be scoped only to the AUM CRM Supabase project.

## Step 2: Install Supabase Agent Skills

Run this inside the development environment terminal:

```bash
npx skills add supabase/agent-skills
```

Recommended place to run:

```text
Replit Shell
```

or local terminal if developing locally.

## Step 3: Security Rules

Never paste these into ChatGPT or commit them to GitHub:

- Supabase service role key
- Database password
- Full DATABASE_URL with password
- JWT secret
- SMTP password
- WhatsApp/API tokens

Use Replit Secrets or environment variables only.

## Step 4: Project Workflow After MCP Setup

Once MCP and Agent Skills are ready, continue in this order:

1. Confirm Supabase connection.
2. Confirm Drizzle schema source path.
3. Export all schema files from the central schema index.
4. Run schema validation/typecheck.
5. Generate or push migrations.
6. Import legacy data bundle.
7. Run smoke test workflow:
   - client
   - lead
   - quotation
   - project
   - work order
   - attendance
   - proof
   - invoice
   - payment
   - profitability summary

## Current AUM CRM Position

The project should continue to treat Drizzle schemas and Express services as the system source of truth.

Supabase MCP is an assistant layer, not the system architecture.
