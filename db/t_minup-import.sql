-- =====================================================================
--  TECHNIKAI ESZKÖZ: a Minupból átemelt, ÉLŐ foglalások betöltése
--
--  Mire való: a régi rendszerben (app.minup.io) már leadott, JÖVŐBELI
--  foglalásokat átemeli az új adatbázisba, hogy a naptár, a résztvevő-
--  lista és az emlékeztető is lássa őket. Az admin felületen nincs kézi
--  foglalásfelvétel, ezért kell ez a script.
--
--  HOL FUTTASD: Supabase → SQL Editor (az ÉLES projektben).
--
--  ================  HASZNÁLAT: KÉT MENETBEN  ========================
--   1. menet — ELLENŐRZÉS: futtasd a fájlt úgy, AHOGY VAN. Nem ír semmit,
--      csak kilistázza, hogy melyik sor talált időpontot és belefér-e.
--   2. menet — BETÖLTÉS: ha minden sor „rendben", vedd ki a 4-5. szakaszt
--      a /* … */ kommentjelek közül, és futtasd újra az egészet.
--  ===================================================================
--
--  ELŐFELTÉTEL:
--    1. Az érintett PROGRAM és IDŐPONT már létezik az új rendszerben,
--       az adminban felvéve — ugyanazzal a dátummal és órával.
--    2. A program „aktív" és nincs archiválva, az időpont nem „elmaradt" —
--       különben a védelmi trigger visszadobja a beszúrást.
--    3. Az időpont max. létszáma elbírja az átemelt foglalásokat.
--
--  MIÉRT „jóváhagyott" státusszal megy be? Mert ezek a foglalások a régi
--  rendszerben már visszaigazoltak. Ráadásul az automatikus visszaigazoló
--  trigger CSAK a „jóváhagyásra vár" státuszra fut — így a régi vendégek
--  nem kapnak váratlan levelet. (A betöltés biztonságból ki is kapcsolja.)
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
--  1) A MINUP-EXPORT SORAI
--     Írd át a VALUES blokkot a valódi adatokra. Egy sor = egy foglalás.
--       program_cim — PONTOSAN úgy, ahogy az új rendszerben a program címe
--       idopont     — helyi (budapesti) idő, 'ÉÉÉÉ-HH-NN ÓÓ:PP' alakban
--       nev, email, telefon, letszam, megjegyzes
-- ---------------------------------------------------------------------
create temporary table minup_import (
  program_cim text,
  idopont     text,
  nev         text,
  email       text,
  telefon     text,
  letszam     integer,
  megjegyzes  text
) on commit drop;

insert into minup_import (program_cim, idopont, nev, email, telefon, letszam, megjegyzes) values
  -- ↓↓↓ PÉLDASOROK — töröld őket, és írd ide a valódi adatokat ↓↓↓
  ('Nápolyi pizza este', '2026-10-05 18:00', 'Minta Anna',  'anna@pelda.hu',  '+36301234567', 2, 'Minupból átemelve'),
  ('Nápolyi pizza este', '2026-10-05 18:00', 'Teszt Béla',  'bela@pelda.hu',  '+36301234568', 4, 'Minupból átemelve'),
  ('Kovászos kenyér',    '2026-10-12 10:00', 'Példa Csaba', 'csaba@pelda.hu', '+36301234569', 3, 'Minupból átemelve')
  -- ↑↑↑ PÉLDASOROK ↑↑↑
;

-- ---------------------------------------------------------------------
--  2) PÁROSÍTÁS az időpontokhoz (program cím + dátum alapján)
--     Ideiglenes tábla (nem nézet), hogy a tranzakció végén gond nélkül
--     el tudjon tűnni.
-- ---------------------------------------------------------------------
create temporary table minup_parositva on commit drop as
select
  m.*,
  i.id          as idopont_id,
  i.max_letszam,
  coalesce((select sum(b.letszam) from public.bookings b
             where b.idopont_id = i.id
               and b.statusz in ('jovahagyasra_var','jovahagyott')), 0) as mar_foglalt
from minup_import m
left join public.workshops w on w.cim = m.program_cim
left join public.idopontok i
       on i.workshop_id = w.id
      and i.idopont = (m.idopont::timestamp at time zone 'Europe/Budapest');

-- ---------------------------------------------------------------------
--  3) ELLENŐRZÉS — EZT NÉZD MEG, MIELŐTT BETÖLTENÉL
--     „nincs párosítva”  → a program/időpont hiányzik vagy más a címe/dátuma
--                          (vedd fel az adminban, és futtasd újra)
--     „maradna” negatív   → nem férne be; emeld a max. létszámot
-- ---------------------------------------------------------------------
select
  case when p.idopont_id is null then '❌ nincs párosítva' else '✔ rendben' end as allapot,
  p.program_cim, p.idopont, p.nev, p.letszam,
  p.max_letszam,
  p.mar_foglalt,
  sum(p.letszam) over (partition by p.idopont_id)                            as most_jonne,
  p.max_letszam - p.mar_foglalt - sum(p.letszam) over (partition by p.idopont_id) as maradna
from minup_parositva p
order by allapot, p.idopont, p.nev;


/* =====================================================================
   A 2. MENETHEZ: vedd ki ezt a blokkot a kommentből (töröld ezt a sort
   és a fájl végi zárósort), majd futtasd újra az egész fájlt.
   =====================================================================

-- ---------------------------------------------------------------------
--  4) BETÖLTÉS
-- ---------------------------------------------------------------------
alter table public.bookings disable trigger trg_uj_foglalas_email;

insert into public.bookings (idopont_id, nev, email, telefon, letszam, megjegyzes, statusz)
select
  p.idopont_id,
  p.nev,
  p.email,
  coalesce(nullif(btrim(p.telefon), ''), '—'),   -- a telefon kötelező mező
  p.letszam,
  p.megjegyzes,
  'jovahagyott'
from minup_parositva p
where p.idopont_id is not null
  -- Kétszeri futtatás elleni védelem: ugyanaz az e-mail ugyanarra az
  -- időpontra csak egyszer kerüljön be.
  and not exists (
    select 1 from public.bookings b
    where b.idopont_id = p.idopont_id
      and lower(b.email) = lower(p.email)
      and b.statusz in ('jovahagyasra_var','jovahagyott')
  );

alter table public.bookings enable trigger trg_uj_foglalas_email;

-- ---------------------------------------------------------------------
--  5) EREDMÉNY — mi lett az érintett időpontokon
-- ---------------------------------------------------------------------
select
  w.cim                                    as program,
  i.idopont at time zone 'Europe/Budapest' as idopont_helyi,
  count(*)                                 as foglalas_db,
  sum(b.letszam)                           as fo,
  i.max_letszam
from public.bookings b
join public.idopontok i on i.id = b.idopont_id
join public.workshops w on w.id = i.workshop_id
where b.statusz in ('jovahagyasra_var','jovahagyott')
group by w.cim, i.idopont, i.max_letszam
order by i.idopont;

   ===================================================================== */

commit;

-- =====================================================================
--  HA VALAMI FÉLREMENT
--  A begin/commit miatt hiba esetén az egész visszagördül, nem marad
--  félkész állapot. Ha a betöltés lefutott, de mégis törölni kell,
--  a megjegyzés alapján megtalálod őket:
--
--    select * from public.bookings where megjegyzes like '%Minupból%';
--    -- delete from public.bookings where megjegyzes like '%Minupból%';
--
--  ELLENŐRIZD UTÁNA: az admin → Foglalások → Jóváhagyott fülön ott
--  vannak-e, és a Naptárban a jó időponthoz kerültek-e.
-- =====================================================================
