alter table public.users
  add column if not exists full_name text;

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null check (
    category in ('vegetables', 'fruits', 'rice_grains', 'meat_seafood')
  ),
  subcategory text not null,
  price_per_kg numeric(10, 2) not null check (price_per_kg >= 0),
  rating numeric(2, 1) not null default 0 check (rating between 0 and 5),
  stock_kg numeric(10, 2) not null default 0 check (stock_kg >= 0),
  seller_id uuid not null,
  seller_name text not null,
  image_url text,
  description text not null default '',
  harvest_date date not null default current_date,
  is_discounted boolean not null default false,
  discount_price numeric(10, 2),
  constraint products_discount_price_check check (
    discount_price is null or
    (discount_price >= 0 and discount_price <= price_per_kg)
  )
);

alter table public.products
  add column if not exists id uuid default gen_random_uuid(),
  add column if not exists name text not null default '',
  add column if not exists category text not null default 'vegetables',
  add column if not exists subcategory text not null default 'Other',
  add column if not exists price_per_kg numeric(10, 2) not null default 0,
  add column if not exists rating numeric(2, 1) not null default 0,
  add column if not exists stock_kg numeric(10, 2) not null default 0,
  add column if not exists seller_id uuid default gen_random_uuid(),
  add column if not exists seller_name text not null default 'Local Seller',
  add column if not exists image_url text,
  add column if not exists description text not null default '',
  add column if not exists harvest_date date not null default current_date,
  add column if not exists is_discounted boolean not null default false,
  add column if not exists discount_price numeric(10, 2);

alter table public.products enable row level security;

create index if not exists products_category_idx
  on public.products (category);

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'products'
      and policyname = 'Authenticated users can browse products'
  ) then
    create policy "Authenticated users can browse products"
      on public.products for select to authenticated
      using (true);
  end if;
end
$$;
