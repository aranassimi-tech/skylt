-- RLS tests. Runs inside one transaction that is rolled back, so it leaves no
-- trace. Works on Supabase (local or hosted, as the postgres user) and on plain
-- PostgreSQL with supabase-shim.sql. Expects seed.sql to be loaded.
-- Run: npm run test:rls   (or: psql "$DATABASE_URL" -f supabase/tests/rls.test.sql)

\set ON_ERROR_STOP on
\set QUIET on
\set SHOW_CONTEXT never
-- only the NOTICE lines (stderr) are interesting
\o /dev/null
begin;

create schema rls_test;
grant usage on schema rls_test to anon, authenticated;

create function rls_test.ok(msg text) returns void language plpgsql as $$
begin raise notice 'OK   %', msg; end $$;

-- the query must return exactly `expected` rows
create function rls_test.expect_rows(q text, expected int, msg text) returns void language plpgsql as $$
declare n int;
begin
  execute format('select count(*) from (%s) x', q) into n;
  if n <> expected then
    raise exception 'FAIL % (fick % rader, väntade %)', msg, n, expected;
  end if;
  perform rls_test.ok(msg);
end $$;

-- the statement must fail
create function rls_test.expect_error(q text, msg text) returns void language plpgsql as $$
begin
  begin
    execute q;
  exception when others then
    perform rls_test.ok(msg || '  [' || sqlerrm || ']');
    return;
  end;
  raise exception 'FAIL % (gick igenom men borde ha nekats)', msg;
end $$;

-- the statement must succeed and change exactly `expected` rows
create function rls_test.expect_changed(q text, expected int, msg text) returns void language plpgsql as $$
declare n int;
begin
  execute q;
  get diagnostics n = row_count;
  if n <> expected then
    raise exception 'FAIL % (ändrade % rader, väntade %)', msg, n, expected;
  end if;
  perform rls_test.ok(msg);
end $$;

grant execute on all functions in schema rls_test to anon, authenticated;

-- Test users (the trigger creates their profiles from app_metadata)
insert into auth.users (id, email, aud, role, raw_app_meta_data) values
('11111111-0000-4000-8000-000000000001', 'admin@kanel.test', 'authenticated', 'authenticated',
  '{"role": "org_admin", "organization_id": "b0000000-0000-4000-8000-000000000001"}'),
('11111111-0000-4000-8000-000000000002', 'editor@kanel.test', 'authenticated', 'authenticated',
  '{"role": "editor", "organization_id": "b0000000-0000-4000-8000-000000000001"}'),
('22222222-0000-4000-8000-000000000001', 'admin@napoli.test', 'authenticated', 'authenticated',
  '{"role": "org_admin", "organization_id": "b0000000-0000-4000-8000-000000000002"}'),
('99999999-0000-4000-8000-000000000001', 'super@skyltstudio.test', 'authenticated', 'authenticated',
  '{"role": "superadmin"}'),
('88888888-0000-4000-8000-000000000001', 'outsider@example.test', 'authenticated', 'authenticated',
  '{}');

-- ===========================================================================
\echo '--- Café Kanel, org_admin'
set local role authenticated;
set local request.jwt.claims = '{"sub": "11111111-0000-4000-8000-000000000001", "role": "authenticated"}';

select rls_test.expect_rows('select * from public.screens', 4, 'ser sina 4 skärmar');
select rls_test.expect_rows('select * from public.products', 11, 'ser sina 11 produkter');
select rls_test.expect_rows('select * from public.organizations', 1, 'ser bara sin egen organisation');
select rls_test.expect_rows('select * from public.packages', 1, 'ser bara sitt eget paket');
select rls_test.expect_rows($q$select * from public.products where organization_id = 'b0000000-0000-4000-8000-000000000002'$q$, 0,
  'kan INTE läsa Napolis produkter');
select rls_test.expect_rows($q$select * from public.screens where organization_id = 'b0000000-0000-4000-8000-000000000002'$q$, 0,
  'kan INTE läsa Napolis skärmar');
select rls_test.expect_rows($q$select * from public.profiles where organization_id = 'b0000000-0000-4000-8000-000000000002'$q$, 0,
  'kan INTE läsa Napolis användare');
select rls_test.expect_changed($q$update public.products set price = 1 where organization_id = 'b0000000-0000-4000-8000-000000000002'$q$, 0,
  'kan INTE ändra Napolis priser');
select rls_test.expect_changed($q$delete from public.screens where id = 'aa000000-0000-4000-8000-000000000101'$q$, 0,
  'kan INTE radera Napolis skärm');
select rls_test.expect_error($q$insert into public.products (organization_id, name, price) values ('b0000000-0000-4000-8000-000000000002', 'Smygprodukt', 1)$q$,
  'kan INTE lägga in produkt hos Napoli');
select rls_test.expect_error($q$select public.publish_screens(array['aa000000-0000-4000-8000-000000000101'::uuid])$q$,
  'kan INTE publicera Napolis skärm');
select rls_test.expect_changed($q$update public.products set price = 36 where id = 'f0000000-0000-4000-8000-000000000001'$q$, 1,
  'kan ändra sitt eget pris');
select rls_test.expect_error($q$update public.screens set published_content = '{}' where id = 'aa000000-0000-4000-8000-000000000001'$q$,
  'kan INTE skriva published_content direkt (bara via Publicera)');
select rls_test.expect_changed($q$update public.screens set draft_content = jsonb_set(draft_content, '{fields,heading}', '"Fika & bröd"') where id = 'aa000000-0000-4000-8000-000000000001'$q$, 1,
  'kan ändra utkast');
select rls_test.expect_rows($q$select 1 where public.publish_screens(array['aa000000-0000-4000-8000-000000000001'::uuid]) = 1$q$, 1,
  'kan publicera sin skärm');
select rls_test.expect_changed($q$update public.organizations set max_screens = 100$q$, 0,
  'kan INTE höja sitt eget skärmtak');
select rls_test.expect_error($q$update public.profiles set role = 'superadmin' where id = '11111111-0000-4000-8000-000000000001'$q$,
  'kan INTE göra sig själv till superadmin');
select rls_test.expect_error($q$update public.profiles set organization_id = 'b0000000-0000-4000-8000-000000000002' where id = '11111111-0000-4000-8000-000000000002'$q$,
  'kan INTE flytta kollega till annan organisation');
select rls_test.expect_error('select * from public.screen_devices', 'kan INTE läsa skärmarnas hemliga nycklar');
select rls_test.expect_changed($q$update public.screens set name = 'Kassan' where id = 'aa000000-0000-4000-8000-000000000001'$q$, 1,
  'kan byta namn på skärm');
reset role;

-- ===========================================================================
\echo '--- Café Kanel, editor'
set local role authenticated;
set local request.jwt.claims = '{"sub": "11111111-0000-4000-8000-000000000002", "role": "authenticated"}';

select rls_test.expect_rows('select * from public.products', 11, 'ser organisationens produkter');
select rls_test.expect_changed($q$update public.products set campaign_price = 30 where id = 'f0000000-0000-4000-8000-000000000002'$q$, 1,
  'kan ändra kampanjpris');
select rls_test.expect_changed($q$update public.screens set draft_content = jsonb_set(draft_content, '{fields,campaign}', 'true') where id = 'aa000000-0000-4000-8000-000000000001'$q$, 1,
  'kan slå på kampanj i utkast');
select rls_test.expect_error($q$update public.screens set name = 'Hej' where id = 'aa000000-0000-4000-8000-000000000001'$q$,
  'kan INTE byta namn på skärm');
select rls_test.expect_error($q$update public.screens set layout = '{"x": 1, "y": 1}' where id = 'aa000000-0000-4000-8000-000000000001'$q$,
  'kan INTE flytta skärm på översikten');
select rls_test.expect_error($q$update public.screens set draft_content = jsonb_set(draft_content, '{template}', '"single-offer"') where id = 'aa000000-0000-4000-8000-000000000001'$q$,
  'kan INTE byta mall');
select rls_test.expect_changed($q$delete from public.screens where id = 'aa000000-0000-4000-8000-000000000001'$q$, 0,
  'kan INTE radera skärm');
select rls_test.expect_error($q$insert into public.screens (organization_id, name) values ('b0000000-0000-4000-8000-000000000001', 'Ny')$q$,
  'kan INTE lägga till skärm');
select rls_test.expect_changed($q$update public.profiles set role = 'org_admin' where id = '11111111-0000-4000-8000-000000000002'$q$, 0,
  'kan INTE ge sig själv högre roll');
reset role;

-- ===========================================================================
\echo '--- Pizzeria Napoli, org_admin'
set local role authenticated;
set local request.jwt.claims = '{"sub": "22222222-0000-4000-8000-000000000001", "role": "authenticated"}';

select rls_test.expect_rows('select * from public.screens', 1, 'ser bara sin egen skärm');
select rls_test.expect_rows('select * from public.products', 2, 'ser bara sina egna 2 produkter');
select rls_test.expect_rows('select * from public.templates', 1, 'ser bara mallar som ingår i paketet');
select rls_test.expect_error($q$update public.screens set draft_content = jsonb_set(draft_content, '{template}', '"single-offer"')$q$,
  'kan INTE välja en mall som inte ingår');
select rls_test.expect_error($q$update public.screens set draft_content = jsonb_set(draft_content, '{theme}', '"christmas"')$q$,
  'kan INTE välja ett tema som inte ingår');
select rls_test.expect_error($q$insert into public.screens (organization_id, name) values ('b0000000-0000-4000-8000-000000000002', 'Skärm 2')$q$,
  'kan INTE gå över paketets skärmtak');
reset role;

-- ===========================================================================
\echo '--- Inloggad utan organisation'
set local role authenticated;
set local request.jwt.claims = '{"sub": "88888888-0000-4000-8000-000000000001", "role": "authenticated"}';
select rls_test.expect_rows('select * from public.profiles', 0, 'har ingen profil');
select rls_test.expect_rows('select * from public.products', 0, 'ser inga produkter');
select rls_test.expect_rows('select * from public.screens', 0, 'ser inga skärmar');
reset role;

-- ===========================================================================
\echo '--- Ej inloggad (anon)'
set local role anon;
set local request.jwt.claims = '{"role": "anon"}';
select rls_test.expect_error('select * from public.products', 'kan INTE läsa produkter');
select rls_test.expect_error('select * from public.screens', 'kan INTE läsa skärmar');
reset role;

-- ===========================================================================
\echo '--- Avstängd kund'
update public.organizations set is_active = false where id = 'b0000000-0000-4000-8000-000000000002';
set local role authenticated;
set local request.jwt.claims = '{"sub": "22222222-0000-4000-8000-000000000001", "role": "authenticated"}';
select rls_test.expect_rows('select * from public.products', 0, 'avstängd kund ser inga produkter');
reset role;

-- ===========================================================================
\echo '--- Superadmin'
set local role authenticated;
set local request.jwt.claims = '{"sub": "99999999-0000-4000-8000-000000000001", "role": "authenticated"}';
select rls_test.expect_rows('select * from public.organizations', 2, 'ser alla organisationer');
select rls_test.expect_rows('select * from public.screens', 5, 'ser alla skärmar');
select rls_test.expect_changed($q$update public.organizations set max_screens = 2 where id = 'b0000000-0000-4000-8000-000000000002'$q$, 1,
  'kan ändra skärmtak');
reset role;

\echo ''
\echo 'Alla RLS-tester gick igenom.'
rollback;
