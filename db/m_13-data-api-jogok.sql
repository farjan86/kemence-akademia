-- =====================================================================
--  DEV-MIGRÁCIÓ: Data API jogok — a táblák „külső kapuja"
--
--  MIÉRT: 2026-10-30-tól a Supabase NEM adja meg automatikusan az új
--  táblákra az API-hozzáférést (changelog #45329). A már meglévő táblák
--  nem érintettek; de ha később új táblát hozunk létre (pl. egy m_14),
--  az grant nélkül „permission denied"-ot adna az oldalnak.
--
--  MIT CSINÁL: pontosan azt mondja ki, amit a Supabase eddig magától
--  csinált — a három szerep (anon = látogató, authenticated = belépett
--  admin, service_role = szerver) eléri a public séma tábláit és
--  sorozatait, és ez a jövőben létrehozott táblákra is érvényes marad.
--  Hogy MELY SOROKAT láthatja/írhatja egy szerep, azt továbbra is az
--  RLS-szabályok döntik el (01-schema.sql) — ez csak a kapu.
--
--  HOL FUTTASD: a MEGLÉVŐ adatbázisokban egyszer — fejlesztői, demó ÉS éles.
--  Új projekthez nem kell: a db/01-schema.sql már tartalmazza (10. pont).
--  Újrafuttatható, nem változtat adaton, nem rontja el a meglévő jogokat.
-- =====================================================================

grant usage on schema public to anon, authenticated, service_role;
grant select, insert, update, delete on all tables    in schema public to anon, authenticated, service_role;
grant usage, select                  on all sequences in schema public to anon, authenticated, service_role;

-- A JÖVŐBEN létrehozott táblákra/sorozatokra is (ez az, amit a Supabase kikapcsolt):
alter default privileges for role postgres in schema public
  grant select, insert, update, delete on tables to anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  grant usage, select on sequences to anon, authenticated, service_role;

-- ---------------------------------------------------------------------
--  ELLENŐRZÉS
-- ---------------------------------------------------------------------
-- Egy meglévő tábla jogai (mindhárom szerepnek 4-4 sor: DELETE, INSERT, SELECT, UPDATE):
-- select grantee, privilege_type
--   from information_schema.role_table_grants
--  where table_schema = 'public' and table_name = 'workshops'
--    and grantee in ('anon','authenticated','service_role')
--  order by grantee, privilege_type;

-- A jövőbeli táblákra vonatkozó alapértelmezés (2 sor kell: r = táblák, S = sorozatok):
-- select defaclobjtype as tipus, defaclacl as jogok
--   from pg_default_acl
--  where defaclnamespace = 'public'::regnamespace and defaclrole = 'postgres'::regrole;
