-- Seed AgriCart produce after creating these two Seller accounts:
-- seller1@agricart.test and seller2@agricart.test.
-- Re-running updates the same seller/product rows instead of duplicating them.
do $$
declare
  v_seller1 public.profiles%rowtype;
  v_seller2 public.profiles%rowtype;
begin
  select * into v_seller1
  from public.profiles
  where lower(email) = lower('seller1@agricart.test')
    and role = 'seller';
  select * into v_seller2
  from public.profiles
  where lower(email) = lower('seller2@agricart.test')
    and role = 'seller';

  if v_seller1.id is null or v_seller2.id is null then
    raise notice
      'Seed skipped: create seller1@agricart.test and seller2@agricart.test with Seller role first.';
    return;
  end if;

  insert into public.products (
    seller_id, seller_name, name, category, subcategory, price_per_kg,
    rating, stock_kg, image_url, description, harvest_date,
    is_discounted, discount_price, is_active, unit
  )
  values
    (
      v_seller1.id, v_seller1.farm_name, 'Tomato', 'vegetables',
      'Fruiting vegetables', 88.00, 4.8, 35,
      'https://placehold.co/600x400?text=Tomato',
      'Juicy tomatoes harvested at peak ripeness.', current_date - 1,
      true, 76.00, true, 'kg'
    ),
    (
      v_seller2.id, v_seller2.farm_name, 'Pechay', 'vegetables',
      'Leafy greens', 52.00, 4.7, 7,
      'https://placehold.co/600x400?text=Pechay',
      'Tender local pechay for soups and stir-fries.', current_date - 1,
      false, null, true, 'kg'
    ),
    (
      v_seller1.id, v_seller1.farm_name, 'Eggplant', 'vegetables',
      'Fruiting vegetables', 68.00, 4.5, 24,
      'https://placehold.co/600x400?text=Eggplant',
      'Firm purple eggplants, freshly harvested.', current_date - 2,
      false, null, true, 'kg'
    ),
    (
      v_seller2.id, v_seller2.farm_name, 'Carabao Mango', 'fruits',
      'Tropical fruits', 135.00, 4.9, 28,
      'https://placehold.co/600x400?text=Carabao+Mango',
      'Sweet Philippine carabao mangoes.', current_date - 1,
      true, 119.00, true, 'kg'
    ),
    (
      v_seller1.id, v_seller1.farm_name, 'Lakatan Banana', 'fruits',
      'Tropical fruits', 72.00, 4.7, 32,
      'https://placehold.co/600x400?text=Lakatan+Banana',
      'Naturally sweet lakatan bananas.', current_date - 2,
      false, null, true, 'kg'
    ),
    (
      v_seller2.id, v_seller2.farm_name, 'Papaya', 'fruits',
      'Tropical fruits', 64.00, 4.6, 0,
      'https://placehold.co/600x400?text=Papaya',
      'Fresh papaya with a mild, sweet flavor.', current_date - 1,
      false, null, true, 'kg'
    ),
    (
      v_seller1.id, v_seller1.farm_name, 'Jasmine Rice', 'rice_grains',
      'White rice', 78.00, 4.8, 85,
      'https://placehold.co/600x400?text=Jasmine+Rice',
      'Aromatic rice from Nueva Ecija growers.', current_date - 7,
      false, null, true, 'kg'
    ),
    (
      v_seller2.id, v_seller2.farm_name, 'Brown Rice', 'rice_grains',
      'Whole grains', 104.00, 4.6, 48,
      'https://placehold.co/600x400?text=Brown+Rice',
      'Nutty whole-grain rice with its bran layer intact.', current_date - 8,
      true, 94.00, true, 'kg'
    ),
    (
      v_seller1.id, v_seller1.farm_name, 'Dinorado Rice', 'rice_grains',
      'White rice', 92.00, 4.7, 60,
      'https://placehold.co/600x400?text=Dinorado+Rice',
      'Fragrant Dinorado rice for everyday meals.', current_date - 6,
      false, null, true, 'kg'
    ),
    (
      v_seller2.id, v_seller2.farm_name, 'Fresh Bangus', 'meat_seafood',
      'Seafood', 225.00, 4.8, 12,
      'https://placehold.co/600x400?text=Bangus',
      'Fresh milkfish, cleaned and chilled.', current_date,
      false, null, true, 'kg'
    ),
    (
      v_seller1.id, v_seller1.farm_name, 'Chicken Breast', 'meat_seafood',
      'Poultry', 198.00, 4.7, 9,
      'https://placehold.co/600x400?text=Chicken+Breast',
      'Fresh trimmed chicken breast, locally raised.', current_date,
      true, 182.00, true, 'kg'
    ),
    (
      v_seller2.id, v_seller2.farm_name, 'Pork Liempo', 'meat_seafood',
      'Pork', 320.00, 4.6, 18,
      'https://placehold.co/600x400?text=Pork+Liempo',
      'Fresh pork belly suitable for grilling or adobo.', current_date,
      false, null, true, 'kg'
    )
  on conflict (seller_id, name) do update
  set seller_name = excluded.seller_name,
      category = excluded.category,
      subcategory = excluded.subcategory,
      price_per_kg = excluded.price_per_kg,
      rating = excluded.rating,
      stock_kg = excluded.stock_kg,
      image_url = excluded.image_url,
      description = excluded.description,
      harvest_date = excluded.harvest_date,
      is_discounted = excluded.is_discounted,
      discount_price = excluded.discount_price,
      is_active = excluded.is_active,
      unit = excluded.unit,
      updated_at = now();

  raise notice 'Seed complete: 12 AgriCart products inserted or updated.';
end;
$$;
