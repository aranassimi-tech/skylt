-- Example data: the customer "Café Kanel" with four screens and the products
-- from the demo, plus a second customer "Pizzeria Napoli" used to prove that
-- customers cannot see each other's data.
-- Users are created separately with `npm run seed:users` (see README).

-- Templates ------------------------------------------------------------------
insert into public.templates (id, key, name, orientation, field_schema) values
('d0000000-0000-4000-8000-000000000001', 'menu-8', 'Meny, upp till 8 rader', 'any', $json$
{"fields": [
  {"key": "heading", "type": "text", "label": "Rubrik", "maxLength": 24},
  {"key": "products", "type": "productList", "label": "Produkter", "min": 1, "max": 8},
  {"key": "campaign", "type": "toggle", "label": "Kampanj på"},
  {"key": "campaignText", "type": "text", "label": "Kampanjtext", "maxLength": 30, "showIf": "campaign"}
]}
$json$),
('d0000000-0000-4000-8000-000000000002', 'single-offer', 'Ett stort erbjudande', 'any', $json$
{"fields": [
  {"key": "heading", "type": "text", "label": "Etikett", "maxLength": 24},
  {"key": "product", "type": "product", "label": "Produkt"},
  {"key": "image", "type": "image", "label": "Bild (valfri, annars produktens bild)"},
  {"key": "campaign", "type": "toggle", "label": "Kampanj på"},
  {"key": "campaignText", "type": "text", "label": "Kampanjtext", "maxLength": 30, "showIf": "campaign"}
]}
$json$);

-- Themes ---------------------------------------------------------------------
insert into public.themes (id, key, name, default_start, default_end) values
('e0000000-0000-4000-8000-000000000001', 'christmas', 'Jul', '11-28', '12-26'),
('e0000000-0000-4000-8000-000000000002', 'halloween', 'Halloween', '10-15', '11-01');

-- Packages -------------------------------------------------------------------
insert into public.packages (id, name, colors, fonts) values
('a0000000-0000-4000-8000-000000000001', 'Kanel',
  '{"primary": "#1f3d33", "accent": "#e3b45c", "paper": "#f6efe3"}',
  '{"heading": "Young Serif", "body": "DM Sans"}'),
('a0000000-0000-4000-8000-000000000002', 'Napoli',
  '{"primary": "#7a1f1f", "accent": "#f2c14e", "paper": "#fff8ec"}',
  '{"heading": "Young Serif", "body": "DM Sans"}');

-- Organizations --------------------------------------------------------------
insert into public.organizations (id, name, package_id, max_screens) values
('b0000000-0000-4000-8000-000000000001', 'Café Kanel', 'a0000000-0000-4000-8000-000000000001', 6),
('b0000000-0000-4000-8000-000000000002', 'Pizzeria Napoli', 'a0000000-0000-4000-8000-000000000002', 1);

insert into public.locations (id, organization_id, name) values
('c0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'Storgatan 12'),
('c0000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000002', 'Hamngatan 3');

-- Entitlements: Kanel has both templates and both themes, Napoli only menu-8
insert into public.entitlements (organization_id, template_id, theme_id) values
('b0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000001', null),
('b0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000002', null),
('b0000000-0000-4000-8000-000000000001', null, 'e0000000-0000-4000-8000-000000000001'),
('b0000000-0000-4000-8000-000000000001', null, 'e0000000-0000-4000-8000-000000000002'),
('b0000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-000000000001', null);

-- Products -------------------------------------------------------------------
insert into public.products (id, organization_id, name, price, campaign_price, category, sort_order) values
('f0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'Kanelbulle', 35, 29, 'Fika', 1),
('f0000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', 'Kardemummabulle', 38, null, 'Fika', 2),
('f0000000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001', 'Lussekatt', 32, null, 'Fika', 3),
('f0000000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000001', 'Kladdkaka', 45, null, 'Fika', 4),
('f0000000-0000-4000-8000-000000000005', 'b0000000-0000-4000-8000-000000000001', 'Cappuccino', 45, null, 'Kaffe & te', 5),
('f0000000-0000-4000-8000-000000000006', 'b0000000-0000-4000-8000-000000000001', 'Caffè latte', 49, 42, 'Kaffe & te', 6),
('f0000000-0000-4000-8000-000000000007', 'b0000000-0000-4000-8000-000000000001', 'Bryggkaffe', 32, null, 'Kaffe & te', 7),
('f0000000-0000-4000-8000-000000000008', 'b0000000-0000-4000-8000-000000000001', 'Chai latte', 52, null, 'Kaffe & te', 8),
('f0000000-0000-4000-8000-000000000009', 'b0000000-0000-4000-8000-000000000001', 'Ostfralla', 59, null, 'Lunch', 9),
('f0000000-0000-4000-8000-000000000010', 'b0000000-0000-4000-8000-000000000001', 'Räksmörgås', 119, null, 'Lunch', 10),
('f0000000-0000-4000-8000-000000000011', 'b0000000-0000-4000-8000-000000000001', 'Pumpasoppa', 89, null, 'Lunch', 11),
('f1000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000002', 'Margherita', 95, null, 'Pizza', 1),
('f1000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000002', 'Capricciosa', 115, 99, 'Pizza', 2);

-- Screens --------------------------------------------------------------------
-- Draft and published start out identical (nothing unpublished).
with s (id, org, loc, name, orientation, content, layout, sort_order, last_seen) as (values
  ('aa000000-0000-4000-8000-000000000001'::uuid, 'b0000000-0000-4000-8000-000000000001'::uuid,
   'c0000000-0000-4000-8000-000000000001'::uuid, 'Meny vänster', 'landscape',
   '{"template": "menu-8", "theme": "halloween", "fields": {"heading": "Fika", "products": ["f0000000-0000-4000-8000-000000000001", "f0000000-0000-4000-8000-000000000002", "f0000000-0000-4000-8000-000000000004", "f0000000-0000-4000-8000-000000000003"], "campaign": false, "campaignText": ""}}'::jsonb,
   '{"x": 36, "y": 90}'::jsonb, 1, now()),
  ('aa000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001',
   'c0000000-0000-4000-8000-000000000001', 'Meny mitten', 'landscape',
   '{"template": "menu-8", "theme": "halloween", "fields": {"heading": "Kaffe & te", "products": ["f0000000-0000-4000-8000-000000000005", "f0000000-0000-4000-8000-000000000006", "f0000000-0000-4000-8000-000000000007", "f0000000-0000-4000-8000-000000000008"], "campaign": true, "campaignText": "Latte + bulle 69:-"}}',
   '{"x": 288, "y": 90}', 2, now()),
  ('aa000000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001',
   'c0000000-0000-4000-8000-000000000001', 'Meny höger', 'landscape',
   '{"template": "menu-8", "theme": "halloween", "fields": {"heading": "Lunch", "products": ["f0000000-0000-4000-8000-000000000009", "f0000000-0000-4000-8000-000000000010", "f0000000-0000-4000-8000-000000000011"], "campaign": false, "campaignText": ""}}',
   '{"x": 540, "y": 90}', 3, now()),
  ('aa000000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000001',
   'c0000000-0000-4000-8000-000000000001', 'Skyltfönster', 'portrait',
   '{"template": "single-offer", "theme": "halloween", "fields": {"heading": "Veckans bulle", "product": "f0000000-0000-4000-8000-000000000001", "image": null, "campaign": true, "campaignText": "Endast denna vecka"}}',
   '{"x": 810, "y": 72}', 4, null),
  ('aa000000-0000-4000-8000-000000000101', 'b0000000-0000-4000-8000-000000000002',
   'c0000000-0000-4000-8000-000000000002', 'Menytavla', 'landscape',
   '{"template": "menu-8", "theme": null, "fields": {"heading": "Pizza", "products": ["f1000000-0000-4000-8000-000000000001", "f1000000-0000-4000-8000-000000000002"], "campaign": false, "campaignText": ""}}',
   '{"x": 36, "y": 90}', 1, now())
)
insert into public.screens
  (id, organization_id, location_id, name, orientation, draft_content, published_content, layout, sort_order, last_seen_at, published_at)
select id, org, loc, name, orientation, content, content, layout, sort_order, last_seen, now() from s;
