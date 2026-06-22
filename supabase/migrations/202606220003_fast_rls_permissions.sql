-- Fast JWT-backed RLS permission layer for AUM Smart Tech CRM
-- Purpose:
--   1. Avoid heavy joins inside row-level security policies.
--   2. Cache role and permissions on public.users.
--   3. Prefer JWT claims for hot-path permission checks.
--   4. Keep tenant isolation as the default safety boundary.
--
-- Required JWT custom claims for maximum performance:
--   role: text
--   tenant_id: uuid/text
--   permissions: text[] or JSON string array
--
-- If JWT claims are not yet present, the helper functions fall back to public.users.

begin;

alter table if exists public.users
  add column if not exists role text,
  add column if not exists permissions text[] not null default '{}';

create index if not exists idx_users_id_role on public.users (id, lower(role));
create index if not exists idx_users_permissions_gin on public.users using gin (permissions);
create index if not exists idx_users_tenant_id on public.users (tenant_id);

update public.users set role = lower(role) where role is not null and role <> lower(role);

create or replace function public.jwt_role()
returns text
language sql
stable
as $$
  select lower(coalesce(
    auth.jwt() ->> 'role',
    auth.jwt() -> 'app_metadata' ->> 'role',
    auth.jwt() -> 'user_metadata' ->> 'role',
    ''
  ));
$$;

create or replace function public.jwt_tenant_id()
returns uuid
language sql
stable
as $$
  select nullif(coalesce(
    auth.jwt() ->> 'tenant_id',
    auth.jwt() -> 'app_metadata' ->> 'tenant_id',
    auth.jwt() -> 'user_metadata' ->> 'tenant_id',
    ''
  ), '')::uuid;
$$;

create or replace function public.jwt_permissions()
returns text[]
language sql
stable
as $$
  select coalesce(
    array(
      select jsonb_array_elements_text(
        case
          when jsonb_typeof(auth.jwt() -> 'permissions') = 'array' then auth.jwt() -> 'permissions'
          when jsonb_typeof(auth.jwt() -> 'app_metadata' -> 'permissions') = 'array' then auth.jwt() -> 'app_metadata' -> 'permissions'
          when jsonb_typeof(auth.jwt() -> 'user_metadata' -> 'permissions') = 'array' then auth.jwt() -> 'user_metadata' -> 'permissions'
          else '[]'::jsonb
        end
      )
    ),
    '{}'
  );
$$;

create or replace function public.current_cached_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    nullif(public.jwt_role(), ''),
    (select lower(u.role) from public.users u where u.id = auth.uid() limit 1),
    ''
  );
$$;

create or replace function public.current_cached_permissions()
returns text[]
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    nullif(public.jwt_permissions(), '{}'),
    (select u.permissions from public.users u where u.id = auth.uid() limit 1),
    '{}'
  );
$$;

create or replace function public.current_cached_tenant_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    public.jwt_tenant_id(),
    (select u.tenant_id from public.users u where u.id = auth.uid() limit 1)
  );
$$;

create or replace function public.can(permission text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    permission = any(public.current_cached_permissions())
    or public.current_cached_role() in ('admin', 'executive'),
    false
  );
$$;

create or replace function public.has_cached_role(allowed_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_cached_role() = any(allowed_roles), false);
$$;

update public.users
set permissions = case lower(role)
  when 'admin' then array['clients:read','clients:create','clients:update','clients:delete','customers:read','customers:create','customers:update','customers:delete','leads:read','leads:create','leads:update','leads:delete','deals:read','deals:create','deals:update','deals:delete','tickets:read','tickets:create','tickets:update','tickets:delete','service_tickets:read','service_tickets:create','service_tickets:update','service_tickets:delete','projects:read','projects:create','projects:update','projects:delete','quotations:read','quotations:create','quotations:update','quotations:delete','invoices:read','invoices:create','invoices:update','invoices:delete','payments:read','payments:create','payments:update','payments:delete','amc_contracts:read','amc_contracts:create','amc_contracts:update','amc_contracts:delete','sops:read','sops:create','sops:update','sops:delete','reports:read','automations:run','users:read','users:create','users:update','users:delete']
  when 'executive' then array['clients:read','customers:read','leads:read','deals:read','tickets:read','service_tickets:read','projects:read','quotations:read','invoices:read','payments:read','amc_contracts:read','sops:read','reports:read','automations:run','users:read']
  when 'sales' then array['clients:read','clients:create','clients:update','customers:read','customers:create','customers:update','leads:read','leads:create','leads:update','deals:read','deals:create','deals:update','quotations:read','quotations:create','quotations:update','follow_ups:read','follow_ups:create','follow_ups:update']
  when 'support' then array['clients:read','customers:read','tickets:read','tickets:create','tickets:update','service_tickets:read','service_tickets:create','service_tickets:update','projects:read','sops:read','sops:create','sops:update','follow_ups:read','follow_ups:create','follow_ups:update']
  when 'technician' then array['clients:read','customers:read','tickets:read','tickets:update','service_tickets:read','service_tickets:update','projects:read','job_updates:read','job_updates:create','job_updates:update','sops:read','sops:update','materials:read','proofs:create']
  when 'finance' then array['clients:read','customers:read','quotations:read','quotations:update','invoices:read','invoices:create','invoices:update','payments:read','payments:create','payments:update','amc_contracts:read','amc_contracts:update','reports:read']
  when 'hr' then array['users:read','users:create','users:update','reports:read']
  when 'client' then array['client_portal:read','tickets:create','tickets:read','invoices:read','deals:read','projects:read']
  else permissions
end
where permissions = '{}'
  and role is not null;

do $$
declare
  tbl text;
  tenant_tables text[] := array['clients','customers','leads','deals','tickets','service_tickets','projects','site_visits','quotations','invoices','payments','amc_contracts','follow_ups','challenges','client_feedback','compliance_records','material_requirements','technician_assignments','job_updates','job_completion_proofs','audit_logs','notification_logs','automation_events','workflow_tasks','automation_webhooks','webhook_deliveries','inventory_items','sop_templates','job_sops'];
begin
  foreach tbl in array tenant_tables loop
    if to_regclass(format('public.%I', tbl)) is not null then
      execute format('alter table public.%I enable row level security', tbl);
      if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = tbl and column_name = 'tenant_id') then
        if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = tbl and policyname = 'fast tenant read by permission') then
          execute format('create policy "fast tenant read by permission" on public.%I for select using (tenant_id = public.current_cached_tenant_id() and (public.can(%L) or public.has_cached_role(array[''admin'', ''executive''])))', tbl, tbl || ':read');
        end if;
        if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = tbl and policyname = 'fast tenant insert by permission') then
          execute format('create policy "fast tenant insert by permission" on public.%I for insert with check (tenant_id = public.current_cached_tenant_id() and (public.can(%L) or public.has_cached_role(array[''admin''])))', tbl, tbl || ':create');
        end if;
        if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = tbl and policyname = 'fast tenant update by permission') then
          execute format('create policy "fast tenant update by permission" on public.%I for update using (tenant_id = public.current_cached_tenant_id() and (public.can(%L) or public.has_cached_role(array[''admin'']))) with check (tenant_id = public.current_cached_tenant_id() and (public.can(%L) or public.has_cached_role(array[''admin''])))', tbl, tbl || ':update', tbl || ':update');
        end if;
        if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = tbl and policyname = 'fast tenant delete by permission') then
          execute format('create policy "fast tenant delete by permission" on public.%I for delete using (tenant_id = public.current_cached_tenant_id() and (public.can(%L) or public.has_cached_role(array[''admin''])))', tbl, tbl || ':delete');
        end if;
      end if;
    end if;
  end loop;
end $$;

do $$
begin
  if to_regclass('public.customers') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'customers' and column_name = 'user_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'customers' and policyname = 'fast client read own customer profile') then
      execute 'create policy "fast client read own customer profile" on public.customers for select using (user_id = auth.uid())';
    end if;
  end if;

  if to_regclass('public.deals') is not null and to_regclass('public.customers') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'deals' and column_name = 'customer_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'deals' and policyname = 'fast client read own deals through customer') then
      execute 'create policy "fast client read own deals through customer" on public.deals for select using (exists (select 1 from public.customers c where c.id = customer_id and c.user_id = auth.uid()))';
    end if;
  end if;

  if to_regclass('public.tickets') is not null and to_regclass('public.customers') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'tickets' and column_name = 'customer_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'tickets' and policyname = 'fast client read own tickets through customer') then
      execute 'create policy "fast client read own tickets through customer" on public.tickets for select using (exists (select 1 from public.customers c where c.id = customer_id and c.user_id = auth.uid()))';
    end if;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'tickets' and policyname = 'fast client create own tickets through customer') then
      execute 'create policy "fast client create own tickets through customer" on public.tickets for insert with check (exists (select 1 from public.customers c where c.id = customer_id and c.user_id = auth.uid()))';
    end if;
  end if;

  if to_regclass('public.invoices') is not null and to_regclass('public.customers') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'invoices' and column_name = 'customer_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'invoices' and policyname = 'fast client read own invoices through customer') then
      execute 'create policy "fast client read own invoices through customer" on public.invoices for select using (exists (select 1 from public.customers c where c.id = customer_id and c.user_id = auth.uid()))';
    end if;
  end if;
end $$;

do $$
declare
  tbl text;
  tenant_tables text[] := array['clients','customers','leads','deals','tickets','service_tickets','projects','site_visits','quotations','invoices','payments','amc_contracts','follow_ups','challenges','client_feedback','compliance_records','material_requirements','technician_assignments','job_updates','job_completion_proofs','audit_logs','notification_logs','automation_events','workflow_tasks','automation_webhooks','webhook_deliveries','inventory_items','sop_templates','job_sops'];
begin
  foreach tbl in array tenant_tables loop
    if to_regclass(format('public.%I', tbl)) is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = tbl and column_name = 'tenant_id') then
      execute format('create index if not exists idx_%I_tenant_id on public.%I (tenant_id)', tbl, tbl);
    end if;
    if to_regclass(format('public.%I', tbl)) is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = tbl and column_name = 'assigned_to') then
      execute format('create index if not exists idx_%I_assigned_to on public.%I (assigned_to)', tbl, tbl);
    end if;
    if to_regclass(format('public.%I', tbl)) is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = tbl and column_name = 'customer_id') then
      execute format('create index if not exists idx_%I_customer_id on public.%I (customer_id)', tbl, tbl);
    end if;
  end loop;

  if to_regclass('public.customers') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'customers' and column_name = 'user_id') then
    execute 'create index if not exists idx_customers_user_id on public.customers (user_id)';
  end if;
end $$;

commit;
