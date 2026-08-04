-- =====================================================================
--  Kemence Akadémia — ÜRES ÁLLAPOT (minden program + foglalás törlése)
--
--  Cél: tiszta lapról indulni a „több időpont" átalakítás előtt.
--  Törli az ÖSSZES foglalást, programot és e-mail naplót, és az azonosító-
--  sorszámot 1-ről újraindítja.
--
--  ⚠️ CSAK fejlesztői környezetben! Éles adaton NE futtasd.
--  Futtatás: Supabase → SQL Editor.
-- =====================================================================

truncate table public.email_log, public.bookings, public.workshops
  restart identity cascade;

-- Ellenőrzés (mindháromnak 0-t kell adnia):
select
  (select count(*) from public.workshops) as programok,
  (select count(*) from public.bookings)  as foglalasok,
  (select count(*) from public.email_log) as email_log;
