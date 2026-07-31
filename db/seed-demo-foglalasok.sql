-- =====================================================================
--  Kemence Akadémia — TISZTA DEMÓ-ADAT (programok + foglalások)
--  ⚠️ Teszt/demó-adat. A tetején MINDENT TÖRÖL (programok, foglalások,
--     e-mail napló) és az azonosító-sorszámot 1-től újraindítja, majd
--     felvisz 8 programot és hozzájuk foglalásokat.
--
--  Ez a fájl ÖNÁLLÓ demó-adat (CSAK fejlesztéshez). Éles DB-n NE futtasd.
--  A 01-schema.sql-be NEM épül be — ez csak demó-adat.
--
--  A 8 program összeállítása:
--    • 2 MÚLTBÉLI (aktív státuszban maradnak → ezeket TE archiválod majd);
--      hozzájuk JÓVÁHAGYOTT és LEMONDOTT foglalások.
--    • 4 JÖVŐBELI, foglalható (aktív); hozzájuk CSAK „jóváhagyásra vár”.
--    • 2 HAMAROSAN (nem foglalható, nincs időpont → nincs foglalás).
--    Kétszer szerepel „Kovászos kenyér” és „Nápolyi pizza” (múlt + jövő,
--    eltérő időponttal) — a név+időpont megkülönböztetés bemutatására.
--
--  Időrend: a foglalások created_at-ja az EGÉSZ listán növekvő, a
--  legrégebbi programtól kezdve → az azonosító (F-100-tól) is így nő.
--
--  Megjegyzés a triggerről: élő (vár/jóváhagyott) foglalást csak AKTÍV
--  programra enged, és figyeli a túlfoglalást. Ezért a múltbéliek is
--  aktívak (archiválás előtt), és sehol nem lépjük túl a max létszámot.
-- =====================================================================

-- Tiszta lap + azonosító újraindítása 1-ről (megjelenítve: F-100-tól)
truncate table public.email_log, public.bookings, public.workshops restart identity cascade;

do $$
declare
  w_kovasz_mult uuid;  w_pizza_mult uuid;   -- múltbéli programok
  w_kovasz_jovo uuid;  w_pizza_jovo uuid;   -- jövőbeli (azonos nevű) programok
  w_cipo        uuid;  w_sutotok     uuid;  -- további jövőbeliek
  w_kalacs      uuid;  w_mezes       uuid;  -- hamarosan érkezők
begin
  -- ===================== PROGRAMOK =====================

  -- 1) MÚLTBÉLI — Kovászos kenyér (2026-05-17) · max 8
  insert into public.workshops (cim, leiras, ar, idopont, varhato_idotartam, max_letszam, statusz)
  values ('Kovászos kenyér workshop',
    'Tanuld meg a kovász gondozását és a kézműves kenyér sütését hagyományos kemencében. A résztvevők saját kovászt és friss cipót is hazavihetnek. A workshop az alapoktól indul, kezdőknek is ajánljuk.',
    24900, timestamptz '2026-05-17 10:00+02', '~5 óra', 8, 'aktiv')
  returning id into w_kovasz_mult;

  -- 2) MÚLTBÉLI — Nápolyi pizza este (2026-06-21) · max 10
  insert into public.workshops (cim, leiras, ar, idopont, varhato_idotartam, max_letszam, statusz)
  values ('Nápolyi pizza este',
    'Igazi nápolyi pizza a kemencéből: tészta-kelesztés, nyújtás, feltétek és a sütés fortélyai. Mindenki több saját pizzát is süt és megkóstol. A vacsora ára az árban benne van.',
    27900, timestamptz '2026-06-21 18:00+02', '~3 óra', 10, 'aktiv')
  returning id into w_pizza_mult;

  -- 3) JÖVŐBELI — Kovászos kenyér (2026-08-16) · max 8  (azonos nevű, mint az 1.)
  insert into public.workshops (cim, leiras, ar, idopont, varhato_idotartam, max_letszam, statusz)
  values ('Kovászos kenyér workshop',
    'Tanuld meg a kovász gondozását és a kézműves kenyér sütését hagyományos kemencében. A résztvevők saját kovászt és friss cipót is hazavihetnek. A workshop az alapoktól indul, kezdőknek is ajánljuk.',
    24900, timestamptz '2026-08-16 10:00+02', '~5 óra', 8, 'aktiv')
  returning id into w_kovasz_jovo;

  -- 4) JÖVŐBELI — Nápolyi pizza este (2026-08-29) · max 10  (azonos nevű, mint a 2.)
  insert into public.workshops (cim, leiras, ar, idopont, varhato_idotartam, max_letszam, statusz)
  values ('Nápolyi pizza este',
    'Igazi nápolyi pizza a kemencéből: tészta-kelesztés, nyújtás, feltétek és a sütés fortélyai. Mindenki több saját pizzát is süt és megkóstol. A vacsora ára az árban benne van.',
    27900, timestamptz '2026-08-29 18:00+02', '~3 óra', 10, 'aktiv')
  returning id into w_pizza_jovo;

  -- 5) JÖVŐBELI — Cipó és bagett (2026-09-12) · max 6 · akciós · szándékosan BETELIK
  insert into public.workshops (cim, leiras, ar, kedvezmenyes_ar, idopont, varhato_idotartam, max_letszam, statusz)
  values ('Cipó és bagett workshop',
    'Ropogós héjú cipó és klasszikus francia bagett készítése a dagasztástól a kemencés sütésig. Megtanuljuk a gőzölés és a bevagdosás technikáját is. Kis létszámú, intenzív műhely.',
    22900, 19900, timestamptz '2026-09-12 14:00+02', '~4 óra', 6, 'aktiv')
  returning id into w_cipo;

  -- 6) JÖVŐBELI — Sütőtökös péksütemények (2026-10-10) · max 12
  insert into public.workshops (cim, leiras, ar, idopont, varhato_idotartam, max_letszam, statusz)
  values ('Sütőtökös péksütemények',
    'Őszi ízek a kemencéből: sütőtökös kenyér, briós és fűszeres teasütemény. Foglalkozunk a tök előkészítésével és a tésztákba építésével. A kész finomságokat hazavihetitek.',
    25900, timestamptz '2026-10-10 10:00+02', '~4 óra', 12, 'aktiv')
  returning id into w_sutotok;

  -- 7) HAMAROSAN — Téli kalács és bejgli (nincs időpont, nem foglalható)
  insert into public.workshops (cim, leiras, statusz)
  values ('Téli kalács és bejgli műhely',
    'Ünnepi fonott kalács és klasszikus mákos-diós bejgli az ünnepekre. Hamarosan meghirdetjük a pontos időpontot — iratkozz fel, hogy elsőként értesülj róla.',
    'hamarosan')
  returning id into w_kalacs;

  -- 8) HAMAROSAN — Mézeskalács-díszítő műhely (nincs időpont, nem foglalható)
  insert into public.workshops (cim, leiras, statusz)
  values ('Mézeskalács-díszítő műhely',
    'Klasszikus mézeskalács sütése és cukormázas díszítése, gyerekeknek és felnőtteknek egyaránt. Hamarosan érkezik a részletes program és az időpont.',
    'hamarosan')
  returning id into w_mezes;

  -- ===================== FOGLALÁSOK =====================
  -- Külön INSERT-ek, időrendben (a legrégebbi programtól). A trigger így
  -- minden sornál pontosan látja a korábbi élő foglalásokat.

  -- 1) Kovászos kenyér (MÚLT) — élő 6/8: jóváhagyott 2+3+1, plusz 2 lemondott
  insert into public.bookings (workshop_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (w_kovasz_mult, 'Kiss Anna',      'anna.kiss@example.com',    '+36301112233', 2, null, 'jovahagyott', timestamptz '2026-04-03 08:45+02');
  insert into public.bookings (workshop_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (w_kovasz_mult, 'Nagy Béla',      'bela.nagy@example.com',    '+36302223344', 3, 'Ketten kezdők vagyunk.', 'jovahagyott', timestamptz '2026-04-06 19:20+02');
  insert into public.bookings (workshop_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (w_kovasz_mult, 'Kovács Emese',   'emese.kovacs@example.com', '+36303334455', 1, null, 'jovahagyott', timestamptz '2026-04-11 12:05+02');
  insert into public.bookings (workshop_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (w_kovasz_mult, 'Szabó Dóra',     'dora.szabo@example.com',   '+36304445566', 2, 'Sajnos közbejött valami.', 'lemondott', timestamptz '2026-04-18 21:30+02');
  insert into public.bookings (workshop_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (w_kovasz_mult, 'Tóth Gábor',     'gabor.toth@example.com',   '+36305556677', 1, null, 'lemondott', timestamptz '2026-05-02 10:15+02');

  -- 2) Nápolyi pizza (MÚLT) — élő 8/10: jóváhagyott 4+2+2, plusz 2 lemondott
  insert into public.bookings (workshop_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (w_pizza_mult, 'Horváth Fanni',  'fanni.horvath@example.com', '+36306667788', 4, 'Céges csapatépítő.', 'jovahagyott', timestamptz '2026-05-19 09:00+02');
  insert into public.bookings (workshop_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (w_pizza_mult, 'Varga Máté',     'mate.varga@example.com',    '+36307778899', 2, null, 'jovahagyott', timestamptz '2026-05-24 18:40+02');
  insert into public.bookings (workshop_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (w_pizza_mult, 'Balogh Rita',    'rita.balogh@example.com',   '+36308889900', 2, null, 'jovahagyott', timestamptz '2026-06-01 14:25+02');
  insert into public.bookings (workshop_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (w_pizza_mult, 'Fekete Ádám',    'adam.fekete@example.com',   '+36309990011', 3, 'Betegség miatt lemondom.', 'lemondott', timestamptz '2026-06-05 20:10+02');
  insert into public.bookings (workshop_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (w_pizza_mult, 'Simon Lilla',    'lilla.simon@example.com',   '+36201234501', 1, null, 'lemondott', timestamptz '2026-06-10 11:00+02');

  -- 3) Kovászos kenyér (JÖVŐ) — csak jóváhagyásra vár: 2+3+1 = 6/8
  insert into public.bookings (workshop_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (w_kovasz_jovo, 'Molnár József', 'jozsef.molnar@example.com', '+36202234502', 2, null, 'jovahagyasra_var', timestamptz '2026-07-05 07:50+02');
  insert into public.bookings (workshop_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (w_kovasz_jovo, 'Németh Klára',  'klara.nemeth@example.com',  '+36203334503', 3, 'Ajándékutalvánnyal fizetnék.', 'jovahagyasra_var', timestamptz '2026-07-08 22:15+02');
  insert into public.bookings (workshop_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (w_kovasz_jovo, 'Papp Levente',  'levente.papp@example.com',  '+36204445504', 1, null, 'jovahagyasra_var', timestamptz '2026-07-10 13:40+02');

  -- 4) Nápolyi pizza (JÖVŐ) — csak jóváhagyásra vár: 4+2+3 = 9/10
  insert into public.bookings (workshop_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (w_pizza_jovo, 'Takács Mónika',  'monika.takacs@example.com', '+36205556505', 4, 'Gluténérzékeny van köztünk.', 'jovahagyasra_var', timestamptz '2026-07-12 09:30+02');
  insert into public.bookings (workshop_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (w_pizza_jovo, 'Oláh Bence',     'bence.olah@example.com',    '+36206667506', 2, null, 'jovahagyasra_var', timestamptz '2026-07-15 17:05+02');
  insert into public.bookings (workshop_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (w_pizza_jovo, 'Fodor Zsófia',   'zsofia.fodor@example.com',  '+36207778507', 3, null, 'jovahagyasra_var', timestamptz '2026-07-17 20:45+02');

  -- 5) Cipó és bagett (JÖVŐ) — csak jóváhagyásra vár: 2+2+2 = 6/6 → BETELT
  insert into public.bookings (workshop_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (w_cipo, 'Juhász Péter',   'peter.juhasz@example.com',  '+36208889508', 2, null, 'jovahagyasra_var', timestamptz '2026-07-19 08:20+02');
  insert into public.bookings (workshop_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (w_cipo, 'Katona Eszter',  'eszter.katona@example.com', '+36209990509', 2, null, 'jovahagyasra_var', timestamptz '2026-07-21 15:55+02');
  insert into public.bookings (workshop_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (w_cipo, 'Halász Tamás',   'tamas.halasz@example.com',  '+36301230510', 2, 'Jönnénk hárman, de csak 2 fér be — 2 főt kérek.', 'jovahagyasra_var', timestamptz '2026-07-23 19:10+02');

  -- 6) Sütőtökös péksütemények (JÖVŐ) — csak jóváhagyásra vár: 2+1 = 3/12
  insert into public.bookings (workshop_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (w_sutotok, 'Pintér Vivien',  'vivien.pinter@example.com', '+36301230511', 2, null, 'jovahagyasra_var', timestamptz '2026-07-25 10:35+02');
  insert into public.bookings (workshop_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (w_sutotok, 'Székely Dániel', 'daniel.szekely@example.com','+36301230512', 1, null, 'jovahagyasra_var', timestamptz '2026-07-28 21:00+02');

end $$;

-- =====================================================================
--  ELLENŐRZÉS
-- =====================================================================

-- Programok időrendben (a hamarosan-érkezők időpont nélkül a végén):
--  A múltbéliek aktívak (te archiválod), a Cipó legyen 0 szabad (Betelt).
select cim,
       coalesce(to_char(idopont, 'YYYY-MM-DD HH24:MI'), '(nincs időpont)') as idopont,
       statusz, max_letszam, szabad_helyek
from public.programok
order by idopont nulls last;

-- Foglalások programonként és státuszonként (db + fő):
select w.cim,
       coalesce(to_char(w.idopont, 'YYYY-MM-DD'), '—') as nap,
       b.statusz,
       count(*)                    as foglalasok,
       coalesce(sum(b.letszam), 0) as fo
from public.bookings b
join public.workshops w on w.id = b.workshop_id
group by w.cim, w.idopont, b.statusz
order by w.idopont nulls last, w.cim, b.statusz;
