-- =====================================================================
--  Migráció: admin naptár-nézet globális beállítás
--  A settings.naptar_nezet szabja meg, hogy a Naptár fül 'lista' (hónaponkénti
--  programlista) vagy 'racs' (normál hónaprács a napokkal) nézetben jelenjen meg.
--  Friss telepítésnél a 01-schema.sql már tartalmazza.
-- =====================================================================

alter table public.settings
  add column if not exists naptar_nezet text not null default 'lista';
