create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  checkout_id uuid not null,
  buyer_id uuid not null references auth.users (id) on delete cascade,
  seller_id uuid not null,
  seller_name text not null,
  fulfillment_type text not null
    check (fulfillment_type in ('delivery', 'pickup')),
  delivery_address text,
  contact_name text,
  contact_phone text,
  payment_method text not null
    check (payment_method in ('cod', 'gcash', 'card')),
  subtotal numeric(12, 2) not null check (subtotal >= 0),
  delivery_fee numeric(12, 2) not null check (delivery_fee >= 0),
  total numeric(12, 2) not null check (total >= 0),
  status text not null default 'pending'
    check (status in (
      'pending', 'confirmed', 'preparing', 'out_for_delivery',
      'ready_for_pickup', 'completed', 'cancelled'
    )),
  eta timestamptz,
  rider_name text,
  rider_phone text,
  created_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete restrict,
  product_name text not null,
  image_path text,
  price_per_kg numeric(10, 2) not null check (price_per_kg >= 0),
  quantity_kg numeric(10, 2) not null check (quantity_kg >= 1),
  line_total numeric(12, 2) not null check (line_total >= 0)
);

create table if not exists public.order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  status text not null
    check (status in (
      'pending', 'confirmed', 'preparing', 'out_for_delivery',
      'ready_for_pickup', 'completed', 'cancelled'
    )),
  created_at timestamptz not null default now()
);

create index if not exists orders_buyer_created_idx
  on public.orders (buyer_id, created_at desc);
create index if not exists orders_seller_created_idx
  on public.orders (seller_id, created_at desc);
create index if not exists orders_checkout_idx
  on public.orders (checkout_id);
create index if not exists order_items_order_idx
  on public.order_items (order_id);
create index if not exists order_status_history_order_created_idx
  on public.order_status_history (order_id, created_at);

alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_status_history enable row level security;

drop policy if exists "Buyers and sellers can read their orders"
  on public.orders;
create policy "Buyers and sellers can read their orders"
  on public.orders for select to authenticated
  using (buyer_id = auth.uid() or seller_id = auth.uid());

drop policy if exists "Buyers can insert their own orders"
  on public.orders;
create policy "Buyers can insert their own orders"
  on public.orders for insert to authenticated
  with check (
    buyer_id = auth.uid()
    and exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.role = 'buyer'
    )
  );

drop policy if exists "Buyers and sellers can read their order items"
  on public.order_items;
create policy "Buyers and sellers can read their order items"
  on public.order_items for select to authenticated
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_id
        and (o.buyer_id = auth.uid() or o.seller_id = auth.uid())
    )
  );

drop policy if exists "Buyers can insert items for their own orders"
  on public.order_items;
create policy "Buyers can insert items for their own orders"
  on public.order_items for insert to authenticated
  with check (
    exists (
      select 1 from public.orders o
      where o.id = order_id and o.buyer_id = auth.uid()
    )
  );

drop policy if exists "Buyers and sellers can read order status history"
  on public.order_status_history;
create policy "Buyers and sellers can read order status history"
  on public.order_status_history for select to authenticated
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_id
        and (o.buyer_id = auth.uid() or o.seller_id = auth.uid())
    )
  );

grant select, insert on public.orders to authenticated;
grant select, insert on public.order_items to authenticated;
grant select on public.order_status_history to authenticated;

create or replace function public.record_order_status_history()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.order_status_history (order_id, status)
    values (new.id, new.status);
  elsif new.status is distinct from old.status then
    insert into public.order_status_history (order_id, status)
    values (new.id, new.status);
  end if;
  return new;
end;
$$;

drop trigger if exists orders_record_status_history on public.orders;
create trigger orders_record_status_history
after insert or update on public.orders
for each row execute function public.record_order_status_history();

create or replace function public.place_order(
  p_checkout_id uuid,
  p_items jsonb,
  p_fulfillment_type text,
  p_delivery_address text,
  p_contact_name text,
  p_contact_phone text,
  p_payment_method text
)
returns setof public.orders
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_buyer_id uuid := auth.uid();
  v_buyer_role text;
  v_item record;
  v_seller record;
  v_product public.products%rowtype;
  v_order public.orders%rowtype;
  v_order_number text;
  v_delivery_fee numeric(12, 2);
  v_actual_price numeric(10, 2);
  v_attempt integer;
  v_inserted boolean;
begin
  if v_buyer_id is null then
    raise exception 'Sign in as a buyer before placing an order.';
  end if;

  select role into v_buyer_role
  from public.users
  where id = v_buyer_id;
  if v_buyer_role is distinct from 'buyer' then
    raise exception 'Only buyer accounts can place orders.';
  end if;

  if p_checkout_id is null then
    raise exception 'Checkout session is missing. Return to your cart and try again.';
  end if;
  if p_fulfillment_type is null
     or p_fulfillment_type not in ('delivery', 'pickup') then
    raise exception 'Choose delivery or pickup.';
  end if;
  if p_payment_method is null
     or p_payment_method not in ('cod', 'gcash', 'card') then
    raise exception 'Choose a supported payment method.';
  end if;
  if p_fulfillment_type = 'delivery' then
    if coalesce(trim(p_delivery_address), '') = '' then
      raise exception 'Enter a delivery address.';
    end if;
    if coalesce(trim(p_contact_name), '') = '' then
      raise exception 'Enter a contact name.';
    end if;
    if coalesce(p_contact_phone, '') !~ '^(09[0-9]{9}|\+639[0-9]{9})$' then
      raise exception 'Enter a valid Philippine mobile number.';
    end if;
  end if;
  if jsonb_typeof(p_items) is distinct from 'array' then
    raise exception 'Your cart is empty.';
  end if;
  if jsonb_array_length(p_items) = 0 then
    raise exception 'Your cart is empty.';
  end if;
  if exists (
    select 1
    from jsonb_to_recordset(p_items) as item(
      product_id uuid,
      quantity_kg numeric,
      expected_price_per_kg numeric
    )
    where item.product_id is null
       or item.quantity_kg is null
       or item.quantity_kg < 1
       or item.expected_price_per_kg is null
  ) then
    raise exception 'Cart contains an invalid item. Each product must be at least 1 kg.';
  end if;

  for v_item in
    select
      item.product_id,
      sum(item.quantity_kg) as quantity_kg,
      min(item.expected_price_per_kg) as min_expected_price,
      max(item.expected_price_per_kg) as max_expected_price
    from jsonb_to_recordset(p_items) as item(
      product_id uuid,
      quantity_kg numeric,
      expected_price_per_kg numeric
    )
    group by item.product_id
    order by item.product_id
  loop
    if v_item.min_expected_price <> v_item.max_expected_price then
      raise exception 'Cart has conflicting prices for one product. Refresh the cart and try again.';
    end if;

    select * into v_product
    from public.products
    where id = v_item.product_id
    for update;
    if not found then
      raise exception 'A product in your cart is no longer available.';
    end if;
    if v_product.stock_kg < v_item.quantity_kg then
      raise exception 'Not enough stock for %: % kg available, % kg requested.',
        v_product.name, v_product.stock_kg, v_item.quantity_kg;
    end if;
    v_actual_price := case
      when v_product.is_discounted and v_product.discount_price is not null
        then v_product.discount_price
      else v_product.price_per_kg
    end;
    if v_item.min_expected_price <> v_actual_price then
      raise exception 'The price for % changed. Refresh your cart and review it again.',
        v_product.name;
    end if;
  end loop;

  for v_item in
    select item.product_id, sum(item.quantity_kg) as quantity_kg
    from jsonb_to_recordset(p_items) as item(
      product_id uuid,
      quantity_kg numeric,
      expected_price_per_kg numeric
    )
    group by item.product_id
    order by item.product_id
  loop
    update public.products
    set stock_kg = stock_kg - v_item.quantity_kg
    where id = v_item.product_id;
  end loop;

  for v_seller in
    select
      product.seller_id,
      max(product.seller_name) as seller_name,
      sum(round(
        item.quantity_kg *
        case
          when product.is_discounted and product.discount_price is not null
            then product.discount_price
          else product.price_per_kg
        end,
        2
      )) as subtotal
    from (
      select item.product_id, sum(item.quantity_kg) as quantity_kg
      from jsonb_to_recordset(p_items) as item(
        product_id uuid,
        quantity_kg numeric,
        expected_price_per_kg numeric
      )
      group by item.product_id
    ) item
    join public.products product on product.id = item.product_id
    group by product.seller_id
    order by product.seller_id
  loop
    v_delivery_fee := case
      when p_fulfillment_type = 'delivery' then 50.00
      else 0.00
    end;
    v_inserted := false;

    for v_attempt in 1..100 loop
      v_order_number := 'AGC' ||
        lpad(floor(random() * 1000000)::bigint::text, 6, '0');
      insert into public.orders (
        order_number, checkout_id, buyer_id, seller_id, seller_name,
        fulfillment_type, delivery_address, contact_name, contact_phone,
        payment_method, subtotal, delivery_fee, total, status
      ) values (
        v_order_number,
        p_checkout_id,
        v_buyer_id,
        v_seller.seller_id,
        v_seller.seller_name,
        p_fulfillment_type,
        case when p_fulfillment_type = 'delivery'
          then trim(p_delivery_address) else null end,
        nullif(trim(p_contact_name), ''),
        nullif(trim(p_contact_phone), ''),
        p_payment_method,
        v_seller.subtotal,
        v_delivery_fee,
        v_seller.subtotal + v_delivery_fee,
        'pending'
      )
      on conflict (order_number) do nothing
      returning * into v_order;

      if found then
        v_inserted := true;
        exit;
      end if;
    end loop;

    if not v_inserted then
      raise exception 'Could not generate a unique order number. Please try again.';
    end if;

    insert into public.order_items (
      order_id, product_id, product_name, image_path,
      price_per_kg, quantity_kg, line_total
    )
    select
      v_order.id,
      product.id,
      product.name,
      product.image_url,
      case
        when product.is_discounted and product.discount_price is not null
          then product.discount_price
        else product.price_per_kg
      end,
      item.quantity_kg,
      round(
        item.quantity_kg *
        case
          when product.is_discounted and product.discount_price is not null
            then product.discount_price
          else product.price_per_kg
        end,
        2
      )
    from (
      select item.product_id, sum(item.quantity_kg) as quantity_kg
      from jsonb_to_recordset(p_items) as item(
        product_id uuid,
        quantity_kg numeric,
        expected_price_per_kg numeric
      )
      group by item.product_id
    ) item
    join public.products product on product.id = item.product_id
    where product.seller_id = v_seller.seller_id;

    return next v_order;
  end loop;
  return;
end;
$$;

create or replace function public.cancel_order(p_order_id uuid)
returns public.orders
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_buyer_id uuid := auth.uid();
  v_buyer_role text;
  v_order public.orders%rowtype;
  v_item record;
begin
  if v_buyer_id is null then
    raise exception 'Sign in as a buyer to cancel an order.';
  end if;

  select role into v_buyer_role
  from public.users
  where id = v_buyer_id;
  if v_buyer_role is distinct from 'buyer' then
    raise exception 'Only buyer accounts can cancel orders.';
  end if;

  select * into v_order
  from public.orders
  where id = p_order_id and buyer_id = v_buyer_id
  for update;
  if not found then
    raise exception 'Order not found.';
  end if;
  if v_order.status <> 'pending' then
    raise exception 'Only pending orders can be cancelled.';
  end if;

  for v_item in
    select product_id, sum(quantity_kg) as quantity_kg
    from public.order_items
    where order_id = v_order.id
    group by product_id
    order by product_id
  loop
    update public.products
    set stock_kg = stock_kg + v_item.quantity_kg
    where id = v_item.product_id;
  end loop;

  update public.orders
  set status = 'cancelled'
  where id = v_order.id
  returning * into v_order;
  return v_order;
end;
$$;

revoke all on function public.place_order(
  uuid, jsonb, text, text, text, text, text
) from public;
grant execute on function public.place_order(
  uuid, jsonb, text, text, text, text, text
) to authenticated;
revoke all on function public.cancel_order(uuid) from public;
grant execute on function public.cancel_order(uuid) to authenticated;
