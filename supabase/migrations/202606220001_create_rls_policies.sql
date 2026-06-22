-- Row Level Security policies for AUM Smart Tech CRM
-- Adapted from Row Level Security Policies.pdf to the live CRM schema.
-- Confirmed assumption: public.users.id = auth.uid()
-- Roles: admin, sales, support, finance, technician, hr, client
-- This migration is defensive: it only creates policies where the target table/columns exist.

begin;

-- =====================================================
-- USERS / EMPLOYEES MODULE
-- =====================================================
do $$
begin
  if to_regclass('public.users') is not null then
    execute 'alter table public.users enable row level security';

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'users' and policyname = 'Users can view own profile') then
      execute 'create policy "Users can view own profile" on public.users for select using (id = auth.uid())';
    end if;

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'users' and policyname = 'Users can update own profile') then
      execute 'create policy "Users can update own profile" on public.users for update using (id = auth.uid()) with check (id = auth.uid())';
    end if;

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'users' and policyname = 'HR view users') then
      execute 'create policy "HR view users" on public.users for select using (exists (select 1 from public.users u where u.id = auth.uid() and u.role = ''hr''))';
    end if;

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'users' and policyname = 'HR insert users') then
      execute 'create policy "HR insert users" on public.users for insert with check (exists (select 1 from public.users u where u.id = auth.uid() and u.role = ''hr''))';
    end if;

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'users' and policyname = 'HR update users') then
      execute 'create policy "HR update users" on public.users for update using (exists (select 1 from public.users u where u.id = auth.uid() and u.role = ''hr'')) with check (exists (select 1 from public.users u where u.id = auth.uid() and u.role = ''hr''))';
    end if;

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'users' and policyname = 'Admin full access users') then
      execute 'create policy "Admin full access users" on public.users for all using (exists (select 1 from public.users u where u.id = auth.uid() and u.role = ''admin'')) with check (exists (select 1 from public.users u where u.id = auth.uid() and u.role = ''admin''))';
    end if;
  end if;
end $$;

-- =====================================================
-- CLIENTS / CUSTOMERS MODULE
-- =====================================================
do $$
begin
  if to_regclass('public.clients') is not null then
    execute 'alter table public.clients enable row level security';

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'clients' and policyname = 'Sales manage clients') then
      execute 'create policy "Sales manage clients" on public.clients for all using (exists (select 1 from public.users u where u.id = auth.uid() and u.role in (''sales'', ''admin''))) with check (exists (select 1 from public.users u where u.id = auth.uid() and u.role in (''sales'', ''admin'')))';
    end if;

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'clients' and policyname = 'Operations view clients') then
      execute 'create policy "Operations view clients" on public.clients for select using (exists (select 1 from public.users u where u.id = auth.uid() and u.role in (''support'', ''finance'', ''technician'', ''hr'')))';
    end if;
  end if;
end $$;

-- Backward-compatible alias if a customers table exists.
do $$
begin
  if to_regclass('public.customers') is not null then
    execute 'alter table public.customers enable row level security';

    if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'customers' and column_name = 'user_id') then
      if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'customers' and policyname = 'Client can view own profile') then
        execute 'create policy "Client can view own profile" on public.customers for select using (user_id = auth.uid())';
      end if;
    end if;

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'customers' and policyname = 'Admin full access customers') then
      execute 'create policy "Admin full access customers" on public.customers for all using (exists (select 1 from public.users u where u.id = auth.uid() and u.role = ''admin'')) with check (exists (select 1 from public.users u where u.id = auth.uid() and u.role = ''admin''))';
    end if;
  end if;
end $$;

-- =====================================================
-- LEADS / DEALS MODULE
-- =====================================================
do $$
begin
  if to_regclass('public.leads') is not null then
    execute 'alter table public.leads enable row level security';

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'leads' and policyname = 'Sales insert leads') then
      execute 'create policy "Sales insert leads" on public.leads for insert with check (exists (select 1 from public.users u where u.id = auth.uid() and u.role in (''sales'', ''admin'')))';
    end if;

    if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'leads' and column_name = 'assigned_to') then
      if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'leads' and policyname = 'Sales view assigned leads') then
        execute 'create policy "Sales view assigned leads" on public.leads for select using (assigned_to = auth.uid() or exists (select 1 from public.users u where u.id = auth.uid() and u.role = ''admin''))';
      end if;

      if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'leads' and policyname = 'Sales update assigned leads') then
        execute 'create policy "Sales update assigned leads" on public.leads for update using (assigned_to = auth.uid() or exists (select 1 from public.users u where u.id = auth.uid() and u.role = ''admin'')) with check (assigned_to = auth.uid() or exists (select 1 from public.users u where u.id = auth.uid() and u.role = ''admin''))';
      end if;
    end if;
  end if;
end $$;

-- Backward-compatible alias if a deals table exists.
do $$
begin
  if to_regclass('public.deals') is not null then
    execute 'alter table public.deals enable row level security';

    if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'deals' and column_name = 'customer_id') then
      if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'deals' and policyname = 'Client view own deals') then
        execute 'create policy "Client view own deals" on public.deals for select using (customer_id = auth.uid())';
      end if;
    end if;

    if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'deals' and column_name = 'assigned_to') then
      if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'deals' and policyname = 'Sales view assigned deals') then
        execute 'create policy "Sales view assigned deals" on public.deals for select using (assigned_to = auth.uid())';
      end if;
      if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'deals' and policyname = 'Sales update assigned deals') then
        execute 'create policy "Sales update assigned deals" on public.deals for update using (assigned_to = auth.uid()) with check (assigned_to = auth.uid())';
      end if;
    end if;

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'deals' and policyname = 'Sales insert deals') then
      execute 'create policy "Sales insert deals" on public.deals for insert with check (exists (select 1 from public.users u where u.id = auth.uid() and u.role = ''sales''))';
    end if;

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'deals' and policyname = 'Admin full access deals') then
      execute 'create policy "Admin full access deals" on public.deals for all using (exists (select 1 from public.users u where u.id = auth.uid() and u.role = ''admin'')) with check (exists (select 1 from public.users u where u.id = auth.uid() and u.role = ''admin''))';
    end if;
  end if;
end $$;

-- =====================================================
-- TICKETS MODULE
-- =====================================================
do $$
begin
  if to_regclass('public.tickets') is not null then
    execute 'alter table public.tickets enable row level security';

    if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'tickets' and column_name = 'customer_id') then
      if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'tickets' and policyname = 'Client view own tickets') then
        execute 'create policy "Client view own tickets" on public.tickets for select using (customer_id = auth.uid())';
      end if;
      if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'tickets' and policyname = 'Client create tickets') then
        execute 'create policy "Client create tickets" on public.tickets for insert with check (customer_id = auth.uid())';
      end if;
    end if;

    if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'tickets' and column_name = 'assigned_to') then
      if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'tickets' and policyname = 'Support and technicians view assigned tickets') then
        execute 'create policy "Support and technicians view assigned tickets" on public.tickets for select using (assigned_to = auth.uid() or exists (select 1 from public.users u where u.id = auth.uid() and u.role = ''admin''))';
      end if;
      if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'tickets' and policyname = 'Support and technicians update assigned tickets') then
        execute 'create policy "Support and technicians update assigned tickets" on public.tickets for update using (assigned_to = auth.uid() or exists (select 1 from public.users u where u.id = auth.uid() and u.role = ''admin'')) with check (assigned_to = auth.uid() or exists (select 1 from public.users u where u.id = auth.uid() and u.role = ''admin''))';
      end if;
    end if;

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'tickets' and policyname = 'Admin full access tickets') then
      execute 'create policy "Admin full access tickets" on public.tickets for all using (exists (select 1 from public.users u where u.id = auth.uid() and u.role = ''admin'')) with check (exists (select 1 from public.users u where u.id = auth.uid() and u.role = ''admin''))';
    end if;
  end if;
end $$;

-- =====================================================
-- SERVICE TICKETS MODULE
-- =====================================================
do $$
begin
  if to_regclass('public.service_tickets') is not null then
    execute 'alter table public.service_tickets enable row level security';

    if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'service_tickets' and column_name = 'assigned_to') then
      if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'service_tickets' and policyname = 'Assigned users view service tickets') then
        execute 'create policy "Assigned users view service tickets" on public.service_tickets for select using (assigned_to = auth.uid() or exists (select 1 from public.users u where u.id = auth.uid() and u.role in (''admin'', ''support'', ''technician'')))';
      end if;
      if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'service_tickets' and policyname = 'Assigned users update service tickets') then
        execute 'create policy "Assigned users update service tickets" on public.service_tickets for update using (assigned_to = auth.uid() or exists (select 1 from public.users u where u.id = auth.uid() and u.role = ''admin'')) with check (assigned_to = auth.uid() or exists (select 1 from public.users u where u.id = auth.uid() and u.role = ''admin''))';
      end if;
    end if;
  end if;
end $$;

-- =====================================================
-- INVOICES MODULE
-- =====================================================
do $$
begin
  if to_regclass('public.invoices') is not null then
    execute 'alter table public.invoices enable row level security';

    if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'invoices' and column_name = 'client_id') then
      if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'invoices' and policyname = 'Client view own invoices') then
        execute 'create policy "Client view own invoices" on public.invoices for select using (client_id = auth.uid())';
      end if;
    elsif exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'invoices' and column_name = 'customer_id') then
      if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'invoices' and policyname = 'Client view own invoices') then
        execute 'create policy "Client view own invoices" on public.invoices for select using (customer_id = auth.uid())';
      end if;
    end if;

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'invoices' and policyname = 'Finance view invoices') then
      execute 'create policy "Finance view invoices" on public.invoices for select using (exists (select 1 from public.users u where u.id = auth.uid() and u.role in (''finance'', ''admin'')))';
    end if;

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'invoices' and policyname = 'Finance update invoices') then
      execute 'create policy "Finance update invoices" on public.invoices for update using (exists (select 1 from public.users u where u.id = auth.uid() and u.role in (''finance'', ''admin''))) with check (exists (select 1 from public.users u where u.id = auth.uid() and u.role in (''finance'', ''admin'')))';
    end if;

    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'invoices' and policyname = 'Admin full access invoices') then
      execute 'create policy "Admin full access invoices" on public.invoices for all using (exists (select 1 from public.users u where u.id = auth.uid() and u.role = ''admin'')) with check (exists (select 1 from public.users u where u.id = auth.uid() and u.role = ''admin''))';
    end if;
  end if;
end $$;

commit;
