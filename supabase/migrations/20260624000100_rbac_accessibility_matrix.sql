-- AUM Smart Tech CRM/Field ERP
-- Step 01: role accessibility matrix for Supabase-backed app navigation and authorization.
-- This migration is additive. It does not remove existing users/permissions tables.

create extension if not exists pgcrypto;

create table if not exists public.app_roles (
  key text primary key,
  name text not null,
  description text,
  hierarchy_level integer not null default 0,
  is_system boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.app_modules (
  key text primary key,
  name text not null,
  module_group text not null,
  description text,
  route_path text,
  sort_order integer not null default 100,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.app_role_module_access (
  role_key text not null references public.app_roles(key) on delete cascade,
  module_key text not null references public.app_modules(key) on delete cascade,
  can_view boolean not null default false,
  can_create boolean not null default false,
  can_update boolean not null default false,
  can_delete boolean not null default false,
  can_approve boolean not null default false,
  can_export boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (role_key, module_key)
);

create table if not exists public.user_role_overrides (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  module_key text not null references public.app_modules(key) on delete cascade,
  can_view boolean,
  can_create boolean,
  can_update boolean,
  can_delete boolean,
  can_approve boolean,
  can_export boolean,
  reason text,
  granted_by uuid references public.users(id) on delete set null,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  unique (tenant_id, user_id, module_key)
);

insert into public.app_roles (key, name, description, hierarchy_level) values
  ('technician', 'Technician', 'Field technician: work orders, SOP execution, attendance, materials issued to own jobs.', 10),
  ('sales', 'Sales', 'Sales team: clients, leads, quotations, follow-ups, sales pipeline.', 20),
  ('support', 'Support', 'Support desk: service tickets, client issues, ticket SOP visibility.', 25),
  ('project_manager', 'Project Manager', 'Project delivery owner: projects, sites, work orders, materials, SOP progress, challenges.', 40),
  ('finance', 'Finance', 'Finance team: invoices, payments, AMC, payroll summaries, exports.', 45),
  ('hr', 'HR', 'HR team: employees, attendance, timesheets, payroll preparation, HR tasks.', 45),
  ('inventory_manager', 'Inventory Manager', 'Inventory/procurement: stock, suppliers, purchase orders, material requests.', 45),
  ('operations_manager', 'Operations Manager', 'Operations manager: projects, technicians, inventory, SOP compliance, service delivery.', 60),
  ('executive', 'Executive', 'Executive leadership: read-only visibility across performance, finance, operations, analytics.', 80),
  ('admin', 'Administrator', 'System administrator: full access, settings, users, automations, audit logs.', 100)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  hierarchy_level = excluded.hierarchy_level;

insert into public.app_modules (key, name, module_group, route_path, sort_order, description) values
  ('dashboard', 'Dashboard', 'core', '/dashboard', 1, 'Role-aware landing dashboard'),
  ('clients', 'Clients', 'crm', '/clients', 10, 'Client master data'),
  ('leads', 'Leads', 'crm', '/leads', 11, 'Lead capture and qualification'),
  ('quotations', 'Quotations', 'crm', '/quotations', 12, 'Customer quotations and quotation items'),
  ('followups', 'Follow-ups', 'crm', '/follow-ups', 13, 'Sales/client follow-up tasks'),
  ('client_feedback', 'Client Feedback', 'crm', '/client-feedback', 14, 'Client feedback and satisfaction'),
  ('projects', 'Projects', 'operations', '/projects', 20, 'Project records and delivery lifecycle'),
  ('sites', 'Sites', 'operations', '/sites', 21, 'Site/location records under projects'),
  ('work_orders', 'Work Orders', 'operations', '/work-orders', 22, 'Field work orders and job cards'),
  ('sops', 'SOPs & AI', 'operations', '/sops', 23, 'SOP templates, execution and field guidance'),
  ('proof_review', 'Proof Review', 'operations', '/proof-review', 24, 'Job completion proof review'),
  ('materials', 'Materials', 'operations', '/materials', 25, 'Project material requirements'),
  ('challenges', 'Challenges', 'operations', '/challenges', 26, 'Project and field blockers'),
  ('service_tickets', 'Service Tickets', 'support', '/service-tickets', 30, 'Customer support/service tickets'),
  ('inventory', 'Inventory', 'inventory', '/inventory', 40, 'Inventory items and stock'),
  ('suppliers', 'Suppliers', 'inventory', '/suppliers', 41, 'Supplier master data'),
  ('purchase_orders', 'Purchase Orders', 'inventory', '/purchase-orders', 42, 'Procurement and purchase orders'),
  ('invoices', 'Invoices', 'finance', '/invoices', 50, 'Customer invoices'),
  ('payments', 'Payments', 'finance', '/payments', 51, 'Payments and collections'),
  ('amc_contracts', 'AMC Contracts', 'finance', '/amc-contracts', 52, 'Annual maintenance contracts'),
  ('finance_reports', 'Finance Reports', 'finance', '/finance', 53, 'Finance and aging reports'),
  ('employees', 'Employees', 'hr', '/employees', 60, 'Employee records'),
  ('attendance', 'Attendance', 'hr', '/attendance', 61, 'Time in/out, GPS and offline attendance'),
  ('timesheets', 'Timesheets', 'hr', '/timesheets', 62, 'Approved work hours before payroll'),
  ('payroll', 'Payroll', 'hr', '/payroll', 63, 'Payroll runs and payslips'),
  ('hr_tasks', 'HR Tasks', 'hr', '/hr-tasks', 64, 'HR task management'),
  ('analytics', 'Analytics', 'analytics', '/analytics', 70, 'Business intelligence dashboards'),
  ('compliance', 'Compliance', 'analytics', '/compliance', 71, 'Compliance status and documents'),
  ('automations', 'Automations', 'admin', '/automations', 90, 'Workflow automation'),
  ('users', 'Users', 'admin', '/users', 91, 'User administration'),
  ('settings', 'Settings', 'admin', '/settings', 92, 'System settings'),
  ('audit_logs', 'Audit Logs', 'admin', '/audit-logs', 93, 'Security and audit history')
on conflict (key) do update set
  name = excluded.name,
  module_group = excluded.module_group,
  route_path = excluded.route_path,
  sort_order = excluded.sort_order,
  description = excluded.description,
  is_active = true;

-- Administrator: full access everywhere.
insert into public.app_role_module_access (role_key, module_key, can_view, can_create, can_update, can_delete, can_approve, can_export)
select 'admin', key, true, true, true, true, true, true from public.app_modules
on conflict (role_key, module_key) do update set
  can_view = true, can_create = true, can_update = true, can_delete = true, can_approve = true, can_export = true;

-- Executive: read/export dashboards and business records, no mutation.
insert into public.app_role_module_access (role_key, module_key, can_view, can_export)
select 'executive', key, true, true
from public.app_modules
where module_group in ('core','crm','operations','support','inventory','finance','hr','analytics')
on conflict (role_key, module_key) do update set can_view = true, can_export = true;

-- Technician: own field execution only. Row-level scoping is handled in app queries/RLS.
insert into public.app_role_module_access (role_key, module_key, can_view, can_create, can_update)
values
  ('technician','dashboard',true,false,false),
  ('technician','work_orders',true,false,true),
  ('technician','sops',true,true,true),
  ('technician','materials',true,true,false),
  ('technician','challenges',true,true,true),
  ('technician','attendance',true,true,true),
  ('technician','service_tickets',true,true,true)
on conflict (role_key, module_key) do update set can_view = excluded.can_view, can_create = excluded.can_create, can_update = excluded.can_update;

-- Sales.
insert into public.app_role_module_access (role_key, module_key, can_view, can_create, can_update, can_export)
values
  ('sales','dashboard',true,false,false,true),
  ('sales','clients',true,true,true,true),
  ('sales','leads',true,true,true,true),
  ('sales','quotations',true,true,true,true),
  ('sales','followups',true,true,true,true),
  ('sales','client_feedback',true,true,true,true),
  ('sales','projects',true,false,false,true),
  ('sales','invoices',true,false,false,true)
on conflict (role_key, module_key) do update set can_view = excluded.can_view, can_create = excluded.can_create, can_update = excluded.can_update, can_export = excluded.can_export;

-- Support.
insert into public.app_role_module_access (role_key, module_key, can_view, can_create, can_update, can_export)
values
  ('support','dashboard',true,false,false,true),
  ('support','clients',true,false,false,true),
  ('support','service_tickets',true,true,true,true),
  ('support','sops',true,false,false,false),
  ('support','proof_review',true,false,false,false),
  ('support','client_feedback',true,true,true,true)
on conflict (role_key, module_key) do update set can_view = excluded.can_view, can_create = excluded.can_create, can_update = excluded.can_update, can_export = excluded.can_export;

-- Project Manager.
insert into public.app_role_module_access (role_key, module_key, can_view, can_create, can_update, can_approve, can_export)
values
  ('project_manager','dashboard',true,false,false,false,true),
  ('project_manager','clients',true,false,false,false,true),
  ('project_manager','projects',true,true,true,true,true),
  ('project_manager','sites',true,true,true,true,true),
  ('project_manager','work_orders',true,true,true,true,true),
  ('project_manager','sops',true,true,true,true,true),
  ('project_manager','proof_review',true,false,true,true,true),
  ('project_manager','materials',true,true,true,true,true),
  ('project_manager','challenges',true,true,true,true,true),
  ('project_manager','attendance',true,false,false,false,true),
  ('project_manager','timesheets',true,false,true,true,true),
  ('project_manager','analytics',true,false,false,false,true)
on conflict (role_key, module_key) do update set can_view = excluded.can_view, can_create = excluded.can_create, can_update = excluded.can_update, can_approve = excluded.can_approve, can_export = excluded.can_export;

-- Operations Manager.
insert into public.app_role_module_access (role_key, module_key, can_view, can_create, can_update, can_approve, can_export)
select 'operations_manager', key, true, key not in ('analytics','compliance'), key not in ('analytics','compliance'), true, true
from public.app_modules
where module_group in ('core','operations','support','inventory','analytics')
on conflict (role_key, module_key) do update set can_view = excluded.can_view, can_create = excluded.can_create, can_update = excluded.can_update, can_approve = excluded.can_approve, can_export = excluded.can_export;

-- Finance.
insert into public.app_role_module_access (role_key, module_key, can_view, can_create, can_update, can_approve, can_export)
values
  ('finance','dashboard',true,false,false,false,true),
  ('finance','clients',true,false,false,false,true),
  ('finance','projects',true,false,false,false,true),
  ('finance','quotations',true,false,false,false,true),
  ('finance','invoices',true,true,true,true,true),
  ('finance','payments',true,true,true,true,true),
  ('finance','amc_contracts',true,true,true,true,true),
  ('finance','finance_reports',true,false,false,false,true),
  ('finance','payroll',true,false,false,false,true),
  ('finance','analytics',true,false,false,false,true)
on conflict (role_key, module_key) do update set can_view = excluded.can_view, can_create = excluded.can_create, can_update = excluded.can_update, can_approve = excluded.can_approve, can_export = excluded.can_export;

-- HR.
insert into public.app_role_module_access (role_key, module_key, can_view, can_create, can_update, can_approve, can_export)
values
  ('hr','dashboard',true,false,false,false,true),
  ('hr','employees',true,true,true,true,true),
  ('hr','attendance',true,true,true,true,true),
  ('hr','timesheets',true,true,true,true,true),
  ('hr','payroll',true,true,true,true,true),
  ('hr','hr_tasks',true,true,true,true,true),
  ('hr','analytics',true,false,false,false,true)
on conflict (role_key, module_key) do update set can_view = excluded.can_view, can_create = excluded.can_create, can_update = excluded.can_update, can_approve = excluded.can_approve, can_export = excluded.can_export;

-- Inventory Manager.
insert into public.app_role_module_access (role_key, module_key, can_view, can_create, can_update, can_approve, can_export)
values
  ('inventory_manager','dashboard',true,false,false,false,true),
  ('inventory_manager','projects',true,false,false,false,true),
  ('inventory_manager','materials',true,true,true,true,true),
  ('inventory_manager','inventory',true,true,true,true,true),
  ('inventory_manager','suppliers',true,true,true,true,true),
  ('inventory_manager','purchase_orders',true,true,true,true,true),
  ('inventory_manager','analytics',true,false,false,false,true)
on conflict (role_key, module_key) do update set can_view = excluded.can_view, can_create = excluded.can_create, can_update = excluded.can_update, can_approve = excluded.can_approve, can_export = excluded.can_export;

create or replace view public.role_access_matrix_v as
select
  r.key as role_key,
  r.name as role_name,
  m.module_group,
  m.key as module_key,
  m.name as module_name,
  m.route_path,
  a.can_view,
  a.can_create,
  a.can_update,
  a.can_delete,
  a.can_approve,
  a.can_export,
  m.sort_order
from public.app_roles r
join public.app_role_module_access a on a.role_key = r.key
join public.app_modules m on m.key = a.module_key
where m.is_active = true
order by r.hierarchy_level, m.sort_order;

create or replace function public.get_role_navigation(p_role_key text)
returns table (
  module_key text,
  module_name text,
  module_group text,
  route_path text,
  can_view boolean,
  can_create boolean,
  can_update boolean,
  can_delete boolean,
  can_approve boolean,
  can_export boolean,
  sort_order integer
)
language sql
stable
security definer
set search_path = public
as $$
  select
    m.key,
    m.name,
    m.module_group,
    m.route_path,
    a.can_view,
    a.can_create,
    a.can_update,
    a.can_delete,
    a.can_approve,
    a.can_export,
    m.sort_order
  from public.app_role_module_access a
  join public.app_modules m on m.key = a.module_key
  where a.role_key = p_role_key
    and a.can_view = true
    and m.is_active = true
  order by m.sort_order;
$$;

alter table public.app_roles enable row level security;
alter table public.app_modules enable row level security;
alter table public.app_role_module_access enable row level security;
alter table public.user_role_overrides enable row level security;

drop policy if exists app_roles_read_all on public.app_roles;
create policy app_roles_read_all on public.app_roles for select using (true);

drop policy if exists app_modules_read_all on public.app_modules;
create policy app_modules_read_all on public.app_modules for select using (true);

drop policy if exists app_role_module_access_read_all on public.app_role_module_access;
create policy app_role_module_access_read_all on public.app_role_module_access for select using (true);

drop policy if exists user_role_overrides_tenant_access on public.user_role_overrides;
create policy user_role_overrides_tenant_access
on public.user_role_overrides
for all
using (
  exists (
    select 1 from public.users u
    where u.id = auth.uid()
      and u.tenant_id = user_role_overrides.tenant_id
  )
)
with check (
  exists (
    select 1 from public.users u
    where u.id = auth.uid()
      and u.tenant_id = user_role_overrides.tenant_id
  )
);
