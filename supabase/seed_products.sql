insert into public.products (
  id, name, category, subcategory, price_per_kg, rating, stock_kg,
  seller_id, seller_name, image_url, description, harvest_date,
  is_discounted, discount_price
) values
(
  'a1000000-0000-4000-8000-000000000001', 'Tomato', 'vegetables',
  'Fruiting vegetables', 95.00, 4.8, 35,
  'b1000000-0000-4000-8000-000000000001', 'Laguna Harvest',
  'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?auto=format&fit=crop&w=800&q=80',
  'Ripe, juicy tomatoes picked at peak freshness.', current_date - 1,
  true, 80.00
),
(
  'a1000000-0000-4000-8000-000000000002', 'Pechay', 'vegetables',
  'Leafy greens', 55.00, 4.7, 24,
  'b1000000-0000-4000-8000-000000000002', 'Baguio Highlands Farm',
  'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=800&q=80',
  'Tender local pechay, ideal for soups and stir-fries.', current_date - 1,
  false, null
),
(
  'a1000000-0000-4000-8000-000000000003', 'Kangkong', 'vegetables',
  'Leafy greens', 38.00, 4.6, 18,
  'b1000000-0000-4000-8000-000000000001', 'Laguna Harvest',
  'https://images.unsplash.com/photo-1518977676601-b53f82aba655?auto=format&fit=crop&w=800&q=80',
  'Fresh water spinach with crisp stems and green leaves.', current_date,
  false, null
),
(
  'a1000000-0000-4000-8000-000000000004', 'Eggplant', 'vegetables',
  'Fruiting vegetables', 72.00, 4.5, 20,
  'b1000000-0000-4000-8000-000000000002', 'Baguio Highlands Farm',
  'https://images.unsplash.com/photo-1653973306754-46cb418f4e62?auto=format&fit=crop&w=800&q=80',
  'Firm purple eggplants, freshly harvested for everyday meals.', current_date - 2,
  false, null
),
(
  'a1000000-0000-4000-8000-000000000005', 'Carabao Mango', 'fruits',
  'Tropical fruits', 140.00, 4.9, 28,
  'b1000000-0000-4000-8000-000000000003', 'Guimaras Sun Farm',
  'https://images.unsplash.com/photo-1553279768-865429fa0078?auto=format&fit=crop&w=800&q=80',
  'Sweet, fragrant Philippine mangoes from Guimaras.', current_date - 1,
  true, 125.00
),
(
  'a1000000-0000-4000-8000-000000000006', 'Lakatan Banana', 'fruits',
  'Tropical fruits', 68.00, 4.7, 32,
  'b1000000-0000-4000-8000-000000000003', 'Guimaras Sun Farm',
  'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?auto=format&fit=crop&w=800&q=80',
  'Naturally sweet lakatan bananas, ready to enjoy.', current_date - 1,
  false, null
),
(
  'a1000000-0000-4000-8000-000000000007', 'Papaya', 'fruits',
  'Tropical fruits', 82.00, 4.6, 16,
  'b1000000-0000-4000-8000-000000000001', 'Laguna Harvest',
  'https://images.unsplash.com/photo-1517282009859-357f824d9e36?auto=format&fit=crop&w=800&q=80',
  'Ripe papaya with soft texture and a mild, sweet flavor.', current_date - 2,
  false, null
),
(
  'a1000000-0000-4000-8000-000000000008', 'Pineapple', 'fruits',
  'Tropical fruits', 98.00, 4.8, 14,
  'b1000000-0000-4000-8000-000000000003', 'Guimaras Sun Farm',
  'https://images.unsplash.com/photo-1550258987-190a2d41a8ba?auto=format&fit=crop&w=800&q=80',
  'Golden pineapple with a refreshing sweet-tart taste.', current_date - 1,
  false, null
),
(
  'a1000000-0000-4000-8000-000000000009', 'Jasmine Rice', 'rice_grains',
  'White rice', 78.00, 4.8, 90,
  'b1000000-0000-4000-8000-000000000004', 'Nueva Ecija Grain Co-op',
  'https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=800&q=80',
  'Aromatic long-grain rice for everyday Filipino meals.', current_date - 4,
  false, null
),
(
  'a1000000-0000-4000-8000-000000000010', 'Brown Rice', 'rice_grains',
  'Whole grains', 105.00, 4.6, 55,
  'b1000000-0000-4000-8000-000000000004', 'Nueva Ecija Grain Co-op',
  'https://images.unsplash.com/photo-1515543237350-b3eea1ec8082?auto=format&fit=crop&w=800&q=80',
  'Nutty whole-grain rice with its bran layer intact.', current_date - 5,
  true, 95.00
),
(
  'a1000000-0000-4000-8000-000000000011', 'Fresh Bangus', 'meat_seafood',
  'Seafood', 230.00, 4.8, 12,
  'b1000000-0000-4000-8000-000000000005', 'Batangas Bay Catch',
  'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=800&q=80',
  'Fresh milkfish, cleaned and ready for your favorite recipe.', current_date,
  false, null
),
(
  'a1000000-0000-4000-8000-000000000012', 'Chicken Breast', 'meat_seafood',
  'Poultry', 190.00, 4.7, 22,
  'b1000000-0000-4000-8000-000000000006', 'Cavite Poultry Farm',
  'https://images.unsplash.com/photo-1604503468506-a8da13d82791?auto=format&fit=crop&w=800&q=80',
  'Fresh chicken breast, trimmed and chilled for cooking.', current_date,
  true, 175.00
)
on conflict (id) do nothing;
