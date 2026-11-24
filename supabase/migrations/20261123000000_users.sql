create table if not exists public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  role text not null check (role in ('buyer', 'seller')),
  created_at timestamptz not null default now()
);

alter table public.users enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'users'
      and policyname = 'Users can view their own profile'
  ) then
    create policy "Users can view their own profile"
      on public.users for select
      using ((select auth.uid()) = id);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'users'
      and policyname = 'Users can create their own profile'
  ) then
    create policy "Users can create their own profile"
      on public.users for insert
      with check ((select auth.uid()) = id);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'users'
      and policyname = 'Users can update their own profile'
  ) then
    create policy "Users can update their own profile"
      on public.users for update
      using ((select auth.uid()) = id)
      with check ((select auth.uid()) = id);
  end if;
end
$$;
