-- Production tenant isolation RLS layer for AUM Smart Tech CRM
-- Assumptions:
--   public.users.id = auth.uid()
--   public.users.tenant_id identifies the user's tenant
--   public.users.role uses one of: admin, sales, support, finance, technician, hr, client
-- This migration is defensive and only applies policies to tables/columns that exist.

begin;

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================
create or replace function public.current_app_user_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid();
$$;

create or replace function public.current_tenant_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select u.tenant_id
  from public.users u
  where u.id = auth.uid()
  limit 1;
$$;

create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select lower(u.role)
  from public.users u
  where u.id = auth.uid()
  limit 1;
$$;

create or replace function public.has_role(allowed_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_user_role() = any(allowed_roles), false);
$$;

create or replace function public.is_tenant_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.has_role(array['admin']);
$$;

-- =====================================================
-- CORE TENANT TABLES
-- =====================================================
alter table if exists public.tenants enable row level security;
alter table if exists public.users enable row level security;

-- Tenants: authenticated users can view only their own tenant.
do $$
begin
  if to_regclass('public.tenants') is not null then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'tenants' and policyname = 'Tenant members view own tenant') then
      execute 'create policy "Tenant members view own tenant" on public.tenants for select using (id = public.current_tenant_id())';
    end if;

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'tenants' and policyname = 'Tenant admins update own tenant') then
      execute 'create policy "Tenant admins update own tenant" on public.tenants for update using (id = public.current_tenant_id() and public.is_tenant_admin()) with check (id = public.current_tenant_id() and public.is_tenant_admin())';
    end if;
  end if;
end $$;

-- Users: users can view/update their own profile; admin/hr can manage users in the same tenant.
do $$
begin
  if to_regclass('public.users') is not null then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'users' and policyname = 'Users view own profile') then
      execute 'create policy "Users view own profile" on public.users for select using (id = auth.uid())';
    end if;

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'users' and policyname = 'Users update own profile') then
      execute 'create policy "Users update own profile" on public.users for update using (id = auth.uid()) with check (id = auth.uid())';
    end if;

    if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'users' and column_name = 'tenant_id') then
      if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'users' and policyname = 'Admin HR view tenant users') then
        execute 'create policy "Admin HR view tenant users" on public.users for select using (tenant_id = public.current_tenant_id() and public.has_role(array[''admin'', ''hr'']))';
      end if;

      if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'users' and policyname = 'Admin HR insert tenant users') then
        execute 'create policy "Admin HR insert tenant users" on public.users for insert with check (tenant_id = public.current_tenant_id() and public.has_role(array[''admin'', ''hr'']))';
      end if;

      if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'users' and policyname = 'Admin HR update tenant users') then
        execute 'create policy "Admin HR update tenant users" on public.users for update using (tenant_id = public.current_tenant_id() and public.has_role(array[''admin'', ''hr''])) with check (tenant_id = public.current_tenant_id() and public.has_role(array[''admin'', ''hr'']))';
      end if;
    end if;
  end if;
end $$;

-- =====================================================
-- GENERIC TENANT ISOLATION FOR TABLES WITH tenant_id
-- =====================================================
do $$
declare
  tbl text;
  tenant_tables text[] := array[
    'audit_logs',
    'clients',
    'leads',
    'site_visits',
    'quotations',
    'projects',
    'technician_assignments',
    'job_updates',
    'material_requirements',
    'invoices',
    'payments',
    'amc_contracts',
    'follow_ups',
    'challenges',
    'client_feedback',
    'compliance_records',
    'sop_templates',
    'job_sops',
    'job_completion_proofs',
    'notification_logs',
    'automation_events',
    'tickets',
    'service_tickets',
    'inventory_items'
  ];
begin
  foreach tbl in array tenant_tables loop
    if to_regclass(format('public.%I', tbl)) is not null
       and exists (
         select 1
         from information_schema.columns
         where table_schema = 'public'
           and table_name = tbl
           and column_name = 'tenant_id'
       ) then
      execute format('alter table public.%I enable row level security', tbl);

      if not exists (
        select 1 from pg_policies
        where schemaname = 'public'
          and tablename = tbl
          and policyname = 'Tenant read own records'
      ) then
        execute format('create policy "Tenant read own records" on public.%I for select using (tenant_id = public.current_tenant_id())', tbl);
      end if;

      if not exists (
        select 1 from pg_policies
        where schemaname = 'public'
          and tablename = tbl
          and policyname = 'Tenant admin full access'
      ) then
        execute format('create policy "Tenant admin full access" on public.%I for all using (tenant_id = public.current_tenant_id() and public.is_tenant_admin()) with check (tenant_id = public.current_tenant_id() and public.is_tenant_admin())', tbl);
      end if;
    end if;
  end loop;
end $$;

-- =====================================================
-- MODULE-SPECIFIC WRITE POLICIES
-- =====================================================

-- Sales: clients and leads.
do $$
begin
  if to_regclass('public.clients') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'clients' and column_name = 'tenant_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'clients' and policyname = 'Sales manage tenant clients') then
      execute 'create policy "Sales manage tenant clients" on public.clients for all using (tenant_id = public.current_tenant_id() and public.has_role(array[''sales'', ''admin''])) with check (tenant_id = public.current_tenant_id() and public.has_role(array[''sales'', ''admin'']))';
    end if;
  end if;

  if to_regclass('public.leads') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'leads' and column_name = 'tenant_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'leads' and policyname = 'Sales manage tenant leads') then
      execute 'create policy "Sales manage tenant leads" on public.leads for all using (tenant_id = public.current_tenant_id() and public.has_role(array[''sales'', ''admin''])) with check (tenant_id = public.current_tenant_id() and public.has_role(array[''sales'', ''admin'']))';
    end if;
  end if;
end $$;

-- Support and technicians: tickets, service tickets, job updates, and technician assignments.
do $$
begin
  if to_regclass('public.tickets') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'tickets' and column_name = 'tenant_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'tickets' and policyname = 'Support technician manage tenant tickets') then
      execute 'create policy "Support technician manage tenant tickets" on public.tickets for all using (tenant_id = public.current_tenant_id() and public.has_role(array[''support'', ''technician'', ''admin''])) with check (tenant_id = public.current_tenant_id() and public.has_role(array[''support'', ''technician'', ''admin'']))';
    end if;
  end if;

  if to_regclass('public.service_tickets') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'service_tickets' and column_name = 'tenant_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'service_tickets' and policyname = 'Support technician manage tenant service tickets') then
      execute 'create policy "Support technician manage tenant service tickets" on public.service_tickets for all using (tenant_id = public.current_tenant_id() and public.has_role(array[''support'', ''technician'', ''admin''])) with check (tenant_id = public.current_tenant_id() and public.has_role(array[''support'', ''technician'', ''admin'']))';
    end if;
  end if;

  if to_regclass('public.job_updates') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'job_updates' and column_name = 'tenant_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'job_updates' and policyname = 'Technicians manage tenant job updates') then
      execute 'create policy "Technicians manage tenant job updates" on public.job_updates for all using (tenant_id = public.current_tenant_id() and public.has_role(array[''technician'', ''support'', ''admin''])) with check (tenant_id = public.current_tenant_id() and public.has_role(array[''technician'', ''support'', ''admin'']))';
    end if;
  end if;

  if to_regclass('public.technician_assignments') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'technician_assignments' and column_name = 'tenant_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'technician_assignments' and policyname = 'Support manage tenant technician assignments') then
      execute 'create policy "Support manage tenant technician assignments" on public.technician_assignments for all using (tenant_id = public.current_tenant_id() and public.has_role(array[''support'', ''admin''])) with check (tenant_id = public.current_tenant_id() and public.has_role(array[''support'', ''admin'']))';
    end if;
  end if;
end $$;

-- Finance: quotations, invoices, payments, AMC contracts.
do $$
begin
  if to_regclass('public.quotations') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'quotations' and column_name = 'tenant_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'quotations' and policyname = 'Finance sales manage tenant quotations') then
      execute 'create policy "Finance sales manage tenant quotations" on public.quotations for all using (tenant_id = public.current_tenant_id() and public.has_role(array[''finance'', ''sales'', ''admin''])) with check (tenant_id = public.current_tenant_id() and public.has_role(array[''finance'', ''sales'', ''admin'']))';
    end if;
  end if;

  if to_regclass('public.invoices') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'invoices' and column_name = 'tenant_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'invoices' and policyname = 'Finance manage tenant invoices') then
      execute 'create policy "Finance manage tenant invoices" on public.invoices for all using (tenant_id = public.current_tenant_id() and public.has_role(array[''finance'', ''admin''])) with check (tenant_id = public.current_tenant_id() and public.has_role(array[''finance'', ''admin'']))';
    end if;
  end if;

  if to_regclass('public.payments') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'payments' and column_name = 'tenant_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'payments' and policyname = 'Finance manage tenant payments') then
      execute 'create policy "Finance manage tenant payments" on public.payments for all using (tenant_id = public.current_tenant_id() and public.has_role(array[''finance'', ''admin''])) with check (tenant_id = public.current_tenant_id() and public.has_role(array[''finance'', ''admin'']))';
    end if;
  end if;

  if to_regclass('public.amc_contracts') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'amc_contracts' and column_name = 'tenant_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'amc_contracts' and policyname = 'Finance support manage tenant amc contracts') then
      execute 'create policy "Finance support manage tenant amc contracts" on public.amc_contracts for all using (tenant_id = public.current_tenant_id() and public.has_role(array[''finance'', ''support'', ''admin''])) with check (tenant_id = public.current_tenant_id() and public.has_role(array[''finance'', ''support'', ''admin'']))';
    end if;
  end if;
end $$;

-- Project operations: projects, site visits, materials, follow ups, challenges, feedback, compliance, SOPs, proofs.
do $$
begin
  if to_regclass('public.projects') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'projects' and column_name = 'tenant_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'projects' and policyname = 'Operations manage tenant projects') then
      execute 'create policy "Operations manage tenant projects" on public.projects for all using (tenant_id = public.current_tenant_id() and public.has_role(array[''sales'', ''support'', ''technician'', ''admin''])) with check (tenant_id = public.current_tenant_id() and public.has_role(array[''sales'', ''support'', ''technician'', ''admin'']))';
    end if;
  end if;

  if to_regclass('public.site_visits') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'site_visits' and column_name = 'tenant_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'site_visits' and policyname = 'Operations manage tenant site visits') then
      execute 'create policy "Operations manage tenant site visits" on public.site_visits for all using (tenant_id = public.current_tenant_id() and public.has_role(array[''sales'', ''support'', ''technician'', ''admin''])) with check (tenant_id = public.current_tenant_id() and public.has_role(array[''sales'', ''support'', ''technician'', ''admin'']))';
    end if;
  end if;

  if to_regclass('public.material_requirements') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'material_requirements' and column_name = 'tenant_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'material_requirements' and policyname = 'Operations manage tenant material requirements') then
      execute 'create policy "Operations manage tenant material requirements" on public.material_requirements for all using (tenant_id = public.current_tenant_id() and public.has_role(array[''support'', ''technician'', ''finance'', ''admin''])) with check (tenant_id = public.current_tenant_id() and public.has_role(array[''support'', ''technician'', ''finance'', ''admin'']))';
    end if;
  end if;

  if to_regclass('public.follow_ups') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'follow_ups' and column_name = 'tenant_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'follow_ups' and policyname = 'Staff manage tenant follow ups') then
      execute 'create policy "Staff manage tenant follow ups" on public.follow_ups for all using (tenant_id = public.current_tenant_id() and public.has_role(array[''sales'', ''support'', ''finance'', ''technician'', ''admin''])) with check (tenant_id = public.current_tenant_id() and public.has_role(array[''sales'', ''support'', ''finance'', ''technician'', ''admin'']))';
    end if;
  end if;

  if to_regclass('public.challenges') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'challenges' and column_name = 'tenant_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'challenges' and policyname = 'Staff manage tenant challenges') then
      execute 'create policy "Staff manage tenant challenges" on public.challenges for all using (tenant_id = public.current_tenant_id() and public.has_role(array[''support'', ''technician'', ''admin''])) with check (tenant_id = public.current_tenant_id() and public.has_role(array[''support'', ''technician'', ''admin'']))';
    end if;
  end if;

  if to_regclass('public.client_feedback') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'client_feedback' and column_name = 'tenant_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'client_feedback' and policyname = 'Staff manage tenant client feedback') then
      execute 'create policy "Staff manage tenant client feedback" on public.client_feedback for all using (tenant_id = public.current_tenant_id() and public.has_role(array[''support'', ''sales'', ''admin''])) with check (tenant_id = public.current_tenant_id() and public.has_role(array[''support'', ''sales'', ''admin'']))';
    end if;
  end if;

  if to_regclass('public.compliance_records') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'compliance_records' and column_name = 'tenant_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'compliance_records' and policyname = 'Staff manage tenant compliance records') then
      execute 'create policy "Staff manage tenant compliance records" on public.compliance_records for all using (tenant_id = public.current_tenant_id() and public.has_role(array[''support'', ''finance'', ''admin''])) with check (tenant_id = public.current_tenant_id() and public.has_role(array[''support'', ''finance'', ''admin'']))';
    end if;
  end if;

  if to_regclass('public.sop_templates') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'sop_templates' and column_name = 'tenant_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'sop_templates' and policyname = 'Admin support manage tenant sop templates') then
      execute 'create policy "Admin support manage tenant sop templates" on public.sop_templates for all using (tenant_id = public.current_tenant_id() and public.has_role(array[''support'', ''admin''])) with check (tenant_id = public.current_tenant_id() and public.has_role(array[''support'', ''admin'']))';
    end if;
  end if;

  if to_regclass('public.job_sops') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'job_sops' and column_name = 'tenant_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'job_sops' and policyname = 'Support technician manage tenant job sops') then
      execute 'create policy "Support technician manage tenant job sops" on public.job_sops for all using (tenant_id = public.current_tenant_id() and public.has_role(array[''support'', ''technician'', ''admin''])) with check (tenant_id = public.current_tenant_id() and public.has_role(array[''support'', ''technician'', ''admin'']))';
    end if;
  end if;

  if to_regclass('public.job_completion_proofs') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'job_completion_proofs' and column_name = 'tenant_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'job_completion_proofs' and policyname = 'Support technician manage tenant completion proofs') then
      execute 'create policy "Support technician manage tenant completion proofs" on public.job_completion_proofs for all using (tenant_id = public.current_tenant_id() and public.has_role(array[''support'', ''technician'', ''admin''])) with check (tenant_id = public.current_tenant_id() and public.has_role(array[''support'', ''technician'', ''admin'']))';
    end if;
  end if;
end $$;

-- Inventory: support, finance, and admin.
do $$
begin
  if to_regclass('public.inventory_items') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'inventory_items' and column_name = 'tenant_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'inventory_items' and policyname = 'Inventory staff manage tenant inventory') then
      execute 'create policy "Inventory staff manage tenant inventory" on public.inventory_items for all using (tenant_id = public.current_tenant_id() and public.has_role(array[''support'', ''finance'', ''admin''])) with check (tenant_id = public.current_tenant_id() and public.has_role(array[''support'', ''finance'', ''admin'']))';
    end if;
  end if;
end $$;

-- System logs: admin-only writes; tenant members can only read their own tenant logs where generic policy exists.
do $$
begin
  if to_regclass('public.audit_logs') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'audit_logs' and column_name = 'tenant_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'audit_logs' and policyname = 'Admins insert tenant audit logs') then
      execute 'create policy "Admins insert tenant audit logs" on public.audit_logs for insert with check (tenant_id = public.current_tenant_id() and public.is_tenant_admin())';
    end if;
  end if;

  if to_regclass('public.notification_logs') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'notification_logs' and column_name = 'tenant_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'notification_logs' and policyname = 'Admins manage tenant notification logs') then
      execute 'create policy "Admins manage tenant notification logs" on public.notification_logs for all using (tenant_id = public.current_tenant_id() and public.is_tenant_admin()) with check (tenant_id = public.current_tenant_id() and public.is_tenant_admin())';
    end if;
  end if;

  if to_regclass('public.automation_events') is not null and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'automation_events' and column_name = 'tenant_id') then
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'automation_events' and policyname = 'Admins manage tenant automation events') then
      execute 'create policy "Admins manage tenant automation events" on public.automation_events for all using (tenant_id = public.current_tenant_id() and public.is_tenant_admin()) with check (tenant_id = public.current_tenant_id() and public.is_tenant_admin())';
    end if;
  end if;
end $$;

-- =====================================================
-- IMPORTANT NON-TENANT CHILD TABLES
-- These tables inherit access through their parent tables.
-- =====================================================
do $$
begin
  if to_regclass('public.quotation_items') is not null then
    execute 'alter table public.quotation_items enable row level security';

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'quotation_items' and policyname = 'Tenant read quotation items') then
      execute 'create policy "Tenant read quotation items" on public.quotation_items for select using (exists (select 1 from public.quotations q where q.id = quotation_id and q.tenant_id = public.current_tenant_id()))';
    end if;

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'quotation_items' and policyname = 'Finance sales manage quotation items') then
      execute 'create policy "Finance sales manage quotation items" on public.quotation_items for all using (exists (select 1 from public.quotations q where q.id = quotation_id and q.tenant_id = public.current_tenant_id()) and public.has_role(array[''finance'', ''sales'', ''admin''])) with check (exists (select 1 from public.quotations q where q.id = quotation_id and q.tenant_id = public.current_tenant_id()) and public.has_role(array[''finance'', ''sales'', ''admin'']))';
    end if;
  end if;

  if to_regclass('public.sop_template_steps') is not null then
    execute 'alter table public.sop_template_steps enable row level security';

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'sop_template_steps' and policyname = 'Tenant read sop template steps') then
      execute 'create policy "Tenant read sop template steps" on public.sop_template_steps for select using (exists (select 1 from public.sop_templates s where s.id = template_id and s.tenant_id = public.current_tenant_id()))';
    end if;

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'sop_template_steps' and policyname = 'Support admin manage sop template steps') then
      execute 'create policy "Support admin manage sop template steps" on public.sop_template_steps for all using (exists (select 1 from public.sop_templates s where s.id = template_id and s.tenant_id = public.current_tenant_id()) and public.has_role(array[''support'', ''admin''])) with check (exists (select 1 from public.sop_templates s where s.id = template_id and s.tenant_id = public.current_tenant_id()) and public.has_role(array[''support'', ''admin'']))';
    end if;
  end if;

  if to_regclass('public.job_sop_steps') is not null then
    execute 'alter table public.job_sop_steps enable row level security';

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'job_sop_steps' and policyname = 'Tenant read job sop steps') then
      execute 'create policy "Tenant read job sop steps" on public.job_sop_steps for select using (exists (select 1 from public.job_sops js where js.id = job_sop_id and js.tenant_id = public.current_tenant_id()))';
    end if;

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'job_sop_steps' and policyname = 'Support technician manage job sop steps') then
      execute 'create policy "Support technician manage job sop steps" on public.job_sop_steps for all using (exists (select 1 from public.job_sops js where js.id = job_sop_id and js.tenant_id = public.current_tenant_id()) and public.has_role(array[''support'', ''technician'', ''admin''])) with check (exists (select 1 from public.job_sops js where js.id = job_sop_id and js.tenant_id = public.current_tenant_id()) and public.has_role(array[''support'', ''technician'', ''admin'']))';
    end if;
  end if;

  if to_regclass('public.ticket_comments') is not null then
    execute 'alter table public.ticket_comments enable row level security';

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'ticket_comments' and policyname = 'Tenant read ticket comments') then
      execute 'create policy "Tenant read ticket comments" on public.ticket_comments for select using (exists (select 1 from public.tickets t where t.id = ticket_id and t.tenant_id = public.current_tenant_id()))';
    end if;

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'ticket_comments' and policyname = 'Support technician add ticket comments') then
      execute 'create policy "Support technician add ticket comments" on public.ticket_comments for insert with check (exists (select 1 from public.tickets t where t.id = ticket_id and t.tenant_id = public.current_tenant_id()) and public.has_role(array[''support'', ''technician'', ''admin'']))';
    end if;
  end if;

  if to_regclass('public.ticket_activity_log') is not null then
    execute 'alter table public.ticket_activity_log enable row level security';

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'ticket_activity_log' and policyname = 'Tenant read ticket activity log') then
      execute 'create policy "Tenant read ticket activity log" on public.ticket_activity_log for select using (exists (select 1 from public.tickets t where t.id = ticket_id and t.tenant_id = public.current_tenant_id()))';
    end if;

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'ticket_activity_log' and policyname = 'Support technician insert ticket activity log') then
      execute 'create policy "Support technician insert ticket activity log" on public.ticket_activity_log for insert with check (exists (select 1 from public.tickets t where t.id = ticket_id and t.tenant_id = public.current_tenant_id()) and public.has_role(array[''support'', ''technician'', ''admin'']))';
    end if;
  end if;

  if to_regclass('public.ticket_sop_link') is not null then
    execute 'alter table public.ticket_sop_link enable row level security';

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'ticket_sop_link' and policyname = 'Tenant read ticket sop links') then
      execute 'create policy "Tenant read ticket sop links" on public.ticket_sop_link for select using (exists (select 1 from public.tickets t where t.id = ticket_id and t.tenant_id = public.current_tenant_id()))';
    end if;

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'ticket_sop_link' and policyname = 'Support technician manage ticket sop links') then
      execute 'create policy "Support technician manage ticket sop links" on public.ticket_sop_link for all using (exists (select 1 from public.tickets t where t.id = ticket_id and t.tenant_id = public.current_tenant_id()) and public.has_role(array[''support'', ''technician'', ''admin''])) with check (exists (select 1 from public.tickets t where t.id = ticket_id and t.tenant_id = public.current_tenant_id()) and public.has_role(array[''support'', ''technician'', ''admin'']))';
    end if;
  end if;
end $$;

commit;
