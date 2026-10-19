-- =====================================================================
--  TESZT-TAKARÍTÁS — az élesítés előtti próba-foglalások és -ajánlatok
--  törlése, ÉS az azonosító-sorszámok visszaállítása 1-re.
--
--  MIÉRT KELL:
--    A foglalás és az ajánlat azonosítója egy automatikus sorszám. Ha a
--    teszt-sorokat csak törlöd, a számláló ott marad, ahol volt — így az
--    első VALÓDI foglalás nem F-100 lenne, hanem F-101, F-102…
--    Ez a szkript a számlálót is visszaállítja, tehát nem marad lyuk.
--
--  MIT TÖRÖL:  az ÖSSZES foglalást és ajánlatkérést, a hozzájuk tartozó
--              levélnaplókkal együtt.
--  MIT NEM:    programokat, időpontokat, egyedi programokat, előadókat,
--              beállításokat, sablonokat — a tartalomhoz nem nyúl.
--
--  ⚠️ ÉLES FORGALOM INDULÁSA UTÁN SOHA NE FUTTASD — valódi foglalásokat
--     törölne. Kizárólag az élesítés előtti tesztek takarítására való.
--
--  HASZNÁLAT: állítsd a `biztos_torlok` kapcsolót true-ra, és futtasd le
--             a Supabase SQL Editorban.
-- =====================================================================

do $$
declare
  -- ⬇⬇⬇ ÁLLÍTSD true-ra, ha tényleg törölni akarsz ⬇⬇⬇
  biztos_torlok boolean := false;

  f integer;
  a integer;
begin
  select count(*) into f from public.bookings;
  select count(*) into a from public.ajanlatok;

  if not biztos_torlok then
    raise exception
      E'Jelenleg % foglalás és % ajánlatkérés van az adatbázisban.\n\n'
       'Ez a szkript MINDET törölné, és a sorszámokat 1-re állítaná vissza.\n'
       'Ha ezt akarod, állítsd a `biztos_torlok` kapcsolót true-ra, és futtasd újra.',
      f, a;
  end if;

  -- A `restart identity` nullázza a sorszám-generátort, a `cascade` pedig
  -- a rájuk hivatkozó naplótáblákat is üríti (email_log, ajanlat_log).
  truncate table public.email_log,   public.bookings  restart identity cascade;
  truncate table public.ajanlat_log, public.ajanlatok restart identity cascade;

  raise notice 'Törölve: % foglalás, % ajánlatkérés. A sorszámok 1-ről indulnak.', f, a;
end $$;

-- =====================================================================
--  ELLENŐRZÉS — mindháromnak 0-t kell adnia, a tartalomnak érintetlennek
-- =====================================================================
select 'foglalás (0 kell)'      as mit, count(*) from public.bookings
union all select 'ajánlatkérés (0 kell)',    count(*) from public.ajanlatok
union all select 'levélnapló (0 kell)',      count(*) from public.email_log
union all select 'ajánlat-napló (0 kell)',   count(*) from public.ajanlat_log
union all select 'program (érintetlen)',     count(*) from public.workshops
union all select 'időpont (érintetlen)',     count(*) from public.idopontok
union all select 'egyedi program (érintetlen)', count(*) from public.egyedi_programok
union all select 'előadó (érintetlen)',      count(*) from public.eloadok;

-- A következő foglalás sorszáma 1 lesz; a MEGJELENÍTETT azonosító ebből és a
-- Beállítások „kezdőérték” mezőjéből áll össze (alapértelmezésben F-100, A-100).
