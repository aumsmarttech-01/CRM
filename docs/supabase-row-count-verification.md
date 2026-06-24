# Supabase Migration Verification

Use this after running:

```bash
DATABASE_URL="$SUPABASE_DATABASE_URL" pnpm --filter @workspace/db run push
pnpm --filter @workspace/scripts run migrate-to-supabase
```

## Required secret state during verification

```text
DATABASE_URL=<current Replit/source PostgreSQL URI>
SUPABASE_DATABASE_URL=<Supabase PostgreSQL URI>
```

Do not permanently switch `DATABASE_URL` until these checks pass.

## Quick row-count verification query

Run this query once against the source database and once against the Supabase target database.

```sql
with table_list(table_name) as (
  values
    ('tenants'),
    ('users'),
    ('refresh_tokens'),
    ('audit_logs'),
    ('permissions'),
    ('role_permissions'),
    ('clients'),
    ('leads'),
    ('site_visits'),
    ('quotations'),
    ('quotation_items'),
    ('projects'),
    ('technician_assignments'),
    ('job_updates'),
    ('material_requirements'),
    ('invoices'),
    ('payments'),
    ('amc_contracts'),
    ('follow_ups'),
    ('challenges'),
    ('client_feedback'),
    ('compliance_records'),
    ('sop_templates'),
    ('sop_template_steps'),
    ('job_sops'),
    ('job_sop_steps'),
    ('job_completion_proofs'),
    ('notification_logs'),
    ('automation_events'),
    ('tickets'),
    ('ticket_comments'),
    ('ticket_activity_log'),
    ('ticket_sop_link'),
    ('service_tickets'),
    ('inventory_items'),
    ('crm_documents'),
    ('integration_settings'),
    ('notification_dispatch_jobs'),
    ('document_processing_jobs'),
    ('whatsapp_threads'),
    ('whatsapp_messages'),
    ('invoice_aging_snapshots'),
    ('workflows'),
    ('workflow_runs'),
    ('workflow_actions_log'),
    ('workflow_scores'),
    ('workflow_ai_suggestions'),
    ('workflow_optimizer_audit')
)
select
  tl.table_name,
  case
    when exists (
      select 1
      from information_schema.tables t
      where t.table_schema = 'public'
        and t.table_name = tl.table_name
    ) then (
      select count(*)::bigint
      from pg_catalog.pg_class c
      join pg_catalog.pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = tl.table_name
    )
    else null
  end as exists_marker
from table_list tl
order by tl.table_name;
```

The query above only confirms table presence. For exact row counts, use the generated dynamic block below.

## Exact row-count block

```sql
do $$
declare
  r record;
  sql text := '';
begin
  create temp table if not exists migration_row_counts (
    table_name text primary key,
    row_count bigint
  ) on commit drop;

  for r in
    select unnest(array[
      'tenants','users','refresh_tokens','audit_logs','permissions','role_permissions',
      'clients','leads','site_visits','quotations','quotation_items','projects',
      'technician_assignments','job_updates','material_requirements','invoices','payments',
      'amc_contracts','follow_ups','challenges','client_feedback','compliance_records',
      'sop_templates','sop_template_steps','job_sops','job_sop_steps','job_completion_proofs',
      'notification_logs','automation_events','tickets','ticket_comments','ticket_activity_log',
      'ticket_sop_link','service_tickets','inventory_items','crm_documents','integration_settings',
      'notification_dispatch_jobs','document_processing_jobs','whatsapp_threads','whatsapp_messages',
      'invoice_aging_snapshots','workflows','workflow_runs','workflow_actions_log','workflow_scores',
      'workflow_ai_suggestions','workflow_optimizer_audit'
    ]) as table_name
  loop
    if exists (
      select 1 from information_schema.tables
      where table_schema = 'public' and table_name = r.table_name
    ) then
      execute format(
        'insert into migration_row_counts(table_name, row_count) select %L, count(*) from public.%I on conflict (table_name) do update set row_count = excluded.row_count',
        r.table_name,
        r.table_name
      );
    else
      insert into migration_row_counts(table_name, row_count)
      values (r.table_name, null)
      on conflict (table_name) do update set row_count = null;
    end if;
  end loop;
end $$;

select *
from migration_row_counts
order by table_name;
```

## Critical business checks

Run these against both databases and compare results.

### Users by role/status

```sql
select role, status, count(*)
from public.users
group by role, status
order by role, status;
```

### Projects by status

```sql
select status, count(*)
from public.projects
group by status
order by status;
```

### Invoices by status

```sql
select status, count(*), coalesce(sum(total_amount), 0) as total_amount
from public.invoices
group by status
order by status;
```

If the invoice amount column is named differently in the live schema, adjust `total_amount` to the actual invoice amount column.

### Quotations by status

```sql
select status, count(*), coalesce(sum(total_amount), 0) as total_amount
from public.quotations
group by status
order by status;
```

If the quotation amount column is named differently in the live schema, adjust `total_amount` to the actual quotation amount column.

### SOP template and step integrity

```sql
select
  st.id,
  st.name,
  count(s.id) as step_count
from public.sop_templates st
left join public.sop_template_steps s on s.template_id = st.id
group by st.id, st.name
order by st.name;
```

If the foreign key column is named differently, adjust `s.template_id` to the actual step-to-template column.

## Cutover rule

Only switch permanently after:

1. Table counts match.
2. Critical business checks match.
3. The app smoke test works with:

```bash
DATABASE_URL="$SUPABASE_DATABASE_URL" pnpm dev
```

Then set:

```text
DATABASE_URL=<Supabase PostgreSQL URI>
SUPABASE_DATABASE_URL=<Supabase PostgreSQL URI>
```
