-- Row Level Security policies for AUM Smart Tech CRM
-- Based on uploaded Row Level Security Policies.pdf.
-- Assumption confirmed: public.users.id = auth.uid()
-- Roles: admin, sales, support, finance, technician, hr, client

begin;

-- =====================================================
-- ENABLE RLS
-- =====================================================
alter table public.customers enable row level security;
alter table public.deals enable row level security;
alter table public.tickets enable row level security;
alter table public.invoices enable row level security;
alter table public.employees enable row level security;

-- =====================================================
-- CUSTOMERS TABLE POLICIES
-- =====================================================
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'customers' and policyname = 'Client can view own profile'
  ) then
    create policy "Client can view own profile"
    on public.customers
    for select
    using (user_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'customers' and policyname = 'Admin full access customers'
  ) then
    create policy "Admin full access customers"
    on public.customers
    for all
    using (
      exists (
        select 1
        from public.users
        where users.id = auth.uid()
          and users.role = 'admin'
      )
    )
    with check (
      exists (
        select 1
        from public.users
        where users.id = auth.uid()
          and users.role = 'admin'
      )
    );
  end if;
end $$;

-- =====================================================
-- DEALS TABLE POLICIES
-- =====================================================
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'deals' and policyname = 'Client view own deals'
  ) then
    create policy "Client view own deals"
    on public.deals
    for select
    using (customer_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'deals' and policyname = 'Sales view assigned deals'
  ) then
    create policy "Sales view assigned deals"
    on public.deals
    for select
    using (assigned_to = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'deals' and policyname = 'Sales update assigned deals'
  ) then
    create policy "Sales update assigned deals"
    on public.deals
    for update
    using (assigned_to = auth.uid())
    with check (assigned_to = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'deals' and policyname = 'Sales insert deals'
  ) then
    create policy "Sales insert deals"
    on public.deals
    for insert
    with check (
      exists (
        select 1
        from public.users
        where users.id = auth.uid()
          and users.role = 'sales'
      )
    );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'deals' and policyname = 'Admin full access deals'
  ) then
    create policy "Admin full access deals"
    on public.deals
    for all
    using (
      exists (
        select 1
        from public.users
        where users.id = auth.uid()
          and users.role = 'admin'
      )
    )
    with check (
      exists (
        select 1
        from public.users
        where users.id = auth.uid()
          and users.role = 'admin'
      )
    );
  end if;
end $$;

-- =====================================================
-- TICKETS TABLE POLICIES
-- =====================================================
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'tickets' and policyname = 'Client view own tickets'
  ) then
    create policy "Client view own tickets"
    on public.tickets
    for select
    using (customer_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'tickets' and policyname = 'Client create tickets'
  ) then
    create policy "Client create tickets"
    on public.tickets
    for insert
    with check (customer_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'tickets' and policyname = 'Support view assigned tickets'
  ) then
    create policy "Support view assigned tickets"
    on public.tickets
    for select
    using (assigned_to = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'tickets' and policyname = 'Support update assigned tickets'
  ) then
    create policy "Support update assigned tickets"
    on public.tickets
    for update
    using (assigned_to = auth.uid())
    with check (assigned_to = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'tickets' and policyname = 'Technician view tickets'
  ) then
    create policy "Technician view tickets"
    on public.tickets
    for select
    using (assigned_to = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'tickets' and policyname = 'Admin full access tickets'
  ) then
    create policy "Admin full access tickets"
    on public.tickets
    for all
    using (
      exists (
        select 1
        from public.users
        where users.id = auth.uid()
          and users.role = 'admin'
      )
    )
    with check (
      exists (
        select 1
        from public.users
        where users.id = auth.uid()
          and users.role = 'admin'
      )
    );
  end if;
end $$;

-- =====================================================
-- INVOICES TABLE POLICIES
-- =====================================================
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'invoices' and policyname = 'Client view own invoices'
  ) then
    create policy "Client view own invoices"
    on public.invoices
    for select
    using (customer_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'invoices' and policyname = 'Finance view invoices'
  ) then
    create policy "Finance view invoices"
    on public.invoices
    for select
    using (
      exists (
        select 1
        from public.users
        where users.id = auth.uid()
          and users.role = 'finance'
      )
    );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'invoices' and policyname = 'Finance update invoices'
  ) then
    create policy "Finance update invoices"
    on public.invoices
    for update
    using (
      exists (
        select 1
        from public.users
        where users.id = auth.uid()
          and users.role = 'finance'
      )
    )
    with check (
      exists (
        select 1
        from public.users
        where users.id = auth.uid()
          and users.role = 'finance'
      )
    );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'invoices' and policyname = 'Admin full access invoices'
  ) then
    create policy "Admin full access invoices"
    on public.invoices
    for all
    using (
      exists (
        select 1
        from public.users
        where users.id = auth.uid()
          and users.role = 'admin'
      )
    )
    with check (
      exists (
        select 1
        from public.users
        where users.id = auth.uid()
          and users.role = 'admin'
      )
    );
  end if;
end $$;

-- =====================================================
-- EMPLOYEES TABLE POLICIES
-- =====================================================
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'employees' and policyname = 'HR view employees'
  ) then
    create policy "HR view employees"
    on public.employees
    for select
    using (
      exists (
        select 1
        from public.users
        where users.id = auth.uid()
          and users.role = 'hr'
      )
    );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'employees' and policyname = 'HR insert employees'
  ) then
    create policy "HR insert employees"
    on public.employees
    for insert
    with check (
      exists (
        select 1
        from public.users
        where users.id = auth.uid()
          and users.role = 'hr'
      )
    );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'employees' and policyname = 'HR update employees'
  ) then
    create policy "HR update employees"
    on public.employees
    for update
    using (
      exists (
        select 1
        from public.users
        where users.id = auth.uid()
          and users.role = 'hr'
      )
    )
    with check (
      exists (
        select 1
        from public.users
        where users.id = auth.uid()
          and users.role = 'hr'
      )
    );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'employees' and policyname = 'Admin full access employees'
  ) then
    create policy "Admin full access employees"
    on public.employees
    for all
    using (
      exists (
        select 1
        from public.users
        where users.id = auth.uid()
          and users.role = 'admin'
      )
    )
    with check (
      exists (
        select 1
        from public.users
        where users.id = auth.uid()
          and users.role = 'admin'
      )
    );
  end if;
end $$;

commit;
