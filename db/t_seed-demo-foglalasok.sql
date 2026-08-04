-- =====================================================================
--  Kemence Akadémia — TISZTA DEMÓ-ADAT (programok + időpontok + foglalások)
--  [ÚJ MODELL: egy program több időpont]
--  ⚠️ Teszt/demó-adat. A tetején MINDENT TÖRÖL (programok, időpontok,
--     foglalások, e-mail napló) és az azonosító-sorszámot 1-től újraindítja.
--
--  Ez a fájl ÖNÁLLÓ demó-adat (CSAK fejlesztéshez). Éles DB-n NE futtasd.
--
--  Az összeállítás VEGYES időpontszámot mutat:
--    • „Kovászos kenyér": 6 időpont (múlt + jövő, eltérő és kedvezményes árakkal)
--    • „Nápolyi pizza":   5 időpont (eltérő/akciós árak)
--    • „Cipó és bagett":  3 időpont (egyik akciós, BETELIK)
--    • „Mézeskalács":     2 időpont (egyik akciós)
--    • „Sütőtökös":       1 időpont
--    • 2 „HAMAROSAN":     időpont nélkül
--  A foglalások VEGYESEN szóródnak: múltbélieken jóváhagyott/lemondott,
--  jövőbelieken jóváhagyásra vár (néhol jóváhagyott is), eltérő telítettséggel.
--
--  A seed nem anon jogkörrel fut, ezért a MÚLTBÉLI időpontra is rögzíthet
--  (historikus adat); a túlfoglalás-védelmet sehol nem lépi túl.
-- =====================================================================

truncate table public.email_log, public.bookings, public.idopontok, public.workshops
  restart identity cascade;

do $$
declare
  w_kov uuid;  w_piz uuid;  w_cip uuid;  w_sut uuid;  w_mez uuid;  w_teli uuid;  w_burek uuid;
  -- Kovászos időpontok
  i_kov1 uuid; i_kov2 uuid; i_kov3 uuid; i_kov4 uuid; i_kov5 uuid; i_kov6 uuid;
  -- Pizza időpontok
  i_piz1 uuid; i_piz2 uuid; i_piz3 uuid; i_piz4 uuid; i_piz5 uuid;
  -- Cipó időpontok
  i_cip1 uuid; i_cip2 uuid; i_cip3 uuid;
  -- Sütőtök / Mézeskalács
  i_sut1 uuid; i_mez1 uuid; i_mez2 uuid;
begin
  -- ===================== PROGRAMOK =====================
  insert into public.workshops (cim, rovid_leiras, leiras, eloado, varhato_idotartam, statusz)
  values ('Kovászos kenyér workshop',
    'Kézműves kovászos kenyér sütése hagyományos kemencében — saját kovászt és cipót hazaviszel.',
    'Tanuld meg a kovász gondozását és a kézműves kenyér sütését hagyományos kemencében. A résztvevők saját kovászt és friss cipót is hazavihetnek.',
    'Nagy Andrea', '~5 óra', 'aktiv') returning id into w_kov;

  insert into public.workshops (cim, rovid_leiras, leiras, eloado, varhato_idotartam, statusz)
  values ('Nápolyi pizza este',
    'Igazi nápolyi pizza a kemencéből — tésztától a sütésig, saját pizzákkal.',
    'Igazi nápolyi pizza a kemencéből: tészta-kelesztés, nyújtás, feltétek és a sütés fortélyai. Mindenki több saját pizzát is süt és megkóstol.',
    'Szabó Zoltán', '~3 óra', 'aktiv') returning id into w_piz;

  insert into public.workshops (cim, rovid_leiras, leiras, varhato_idotartam, statusz)
  values ('Cipó és bagett workshop',
    'Ropogós cipó és francia bagett a dagasztástól a kemencés sütésig.',
    'Ropogós héjú cipó és klasszikus francia bagett a dagasztástól a kemencés sütésig. Kis létszámú, intenzív műhely.',
    '~4 óra', 'aktiv') returning id into w_cip;

  insert into public.workshops (cim, rovid_leiras, leiras, eloado, varhato_idotartam, statusz)
  values ('Sütőtökös péksütemények',
    'Őszi sütőtökös péksütemények a kemencéből — vidd haza a finomságokat.',
    'Őszi ízek a kemencéből: sütőtökös kenyér, briós és fűszeres teasütemény. A kész finomságokat hazavihetitek.',
    'Kis Petra, Nagy Andrea', '~4 óra', 'aktiv') returning id into w_sut;

  insert into public.workshops (cim, rovid_leiras, leiras, varhato_idotartam, statusz)
  values ('Mézeskalács-díszítő műhely',
    'Mézeskalács sütése és cukormázas díszítése, kicsiknek és nagyoknak.',
    'Klasszikus mézeskalács sütése és cukormázas díszítése, gyerekeknek és felnőtteknek egyaránt.',
    '~3 óra', 'aktiv') returning id into w_mez;

  insert into public.workshops (cim, rovid_leiras, leiras, statusz)
  values ('Téli kalács és bejgli műhely',
    'Ünnepi fonott kalács és mákos-diós bejgli — hamarosan időponttal.',
    'Ünnepi fonott kalács és klasszikus mákos-diós bejgli. Hamarosan meghirdetjük a pontos időpontot.',
    'hamarosan') returning id into w_teli;

  insert into public.workshops (cim, rovid_leiras, leiras, statusz)
  values ('Kemencés burek workshop',
    'Rétestésztás burek édesen, túrósan és húsosan — hamarosan.',
    'Rétestésztás burek édes és sós-túrós, valamint húsos változatban. Hamarosan érkezik a részletes program.',
    'hamarosan') returning id into w_burek;

  -- ===================== IDŐPONTOK =====================
  -- Kovászos — 6 időpont (2 múlt + 4 jövő), eltérő és kedvezményes árak
  insert into public.idopontok (workshop_id, idopont, ar, kedvezmenyes_ar, max_letszam) values
    (w_kov, timestamptz '2026-05-17 10:00+02', 24900, null,  8) returning id into i_kov1;
  insert into public.idopontok (workshop_id, idopont, ar, kedvezmenyes_ar, max_letszam) values
    (w_kov, timestamptz '2026-06-14 10:00+02', 24900, null,  8) returning id into i_kov2;
  insert into public.idopontok (workshop_id, idopont, ar, kedvezmenyes_ar, max_letszam) values
    (w_kov, timestamptz '2026-08-16 10:00+02', 24900, null,  8) returning id into i_kov3;
  insert into public.idopontok (workshop_id, idopont, ar, kedvezmenyes_ar, max_letszam) values
    (w_kov, timestamptz '2026-08-30 10:00+02', 26900, null,  8) returning id into i_kov4;   -- drágább
  insert into public.idopontok (workshop_id, idopont, ar, kedvezmenyes_ar, max_letszam) values
    (w_kov, timestamptz '2026-09-13 10:00+02', 24900, 21900, 8) returning id into i_kov5;   -- akciós
  insert into public.idopontok (workshop_id, idopont, ar, kedvezmenyes_ar, max_letszam) values
    (w_kov, timestamptz '2026-10-11 10:00+02', 26900, null, 10) returning id into i_kov6;

  -- Pizza — 5 időpont (1 múlt + 4 jövő)
  insert into public.idopontok (workshop_id, idopont, ar, kedvezmenyes_ar, max_letszam) values
    (w_piz, timestamptz '2026-06-21 18:00+02', 27900, null, 10) returning id into i_piz1;
  insert into public.idopontok (workshop_id, idopont, ar, kedvezmenyes_ar, max_letszam) values
    (w_piz, timestamptz '2026-08-22 18:00+02', 27900, null, 10) returning id into i_piz2;
  insert into public.idopontok (workshop_id, idopont, ar, kedvezmenyes_ar, max_letszam) values
    (w_piz, timestamptz '2026-09-05 18:00+02', 29900, null, 10) returning id into i_piz3;   -- drágább (hétvége)
  insert into public.idopontok (workshop_id, idopont, ar, kedvezmenyes_ar, max_letszam) values
    (w_piz, timestamptz '2026-09-19 18:00+02', 27900, 24900, 10) returning id into i_piz4;  -- akciós
  insert into public.idopontok (workshop_id, idopont, ar, kedvezmenyes_ar, max_letszam) values
    (w_piz, timestamptz '2026-10-17 18:00+02', 29900, null, 12) returning id into i_piz5;

  -- Cipó — 3 időpont (egyik akciós, BETELIK)
  insert into public.idopontok (workshop_id, idopont, ar, kedvezmenyes_ar, max_letszam) values
    (w_cip, timestamptz '2026-08-23 14:00+02', 22900, 19900, 6) returning id into i_cip1;   -- akciós, betelik
  insert into public.idopontok (workshop_id, idopont, ar, kedvezmenyes_ar, max_letszam) values
    (w_cip, timestamptz '2026-09-20 14:00+02', 22900, null,  6) returning id into i_cip2;
  insert into public.idopontok (workshop_id, idopont, ar, kedvezmenyes_ar, max_letszam) values
    (w_cip, timestamptz '2026-10-18 14:00+02', 23900, null,  6) returning id into i_cip3;   -- (foglalás nélkül marad)

  -- Sütőtök — 1 időpont
  insert into public.idopontok (workshop_id, idopont, ar, kedvezmenyes_ar, max_letszam) values
    (w_sut, timestamptz '2026-10-10 10:00+02', 25900, null, 12) returning id into i_sut1;

  -- Mézeskalács — 2 időpont (egyik akciós)
  insert into public.idopontok (workshop_id, idopont, ar, kedvezmenyes_ar, max_letszam) values
    (w_mez, timestamptz '2026-11-28 15:00+01', 18900, null, 12) returning id into i_mez1;   -- (foglalás nélkül)
  insert into public.idopontok (workshop_id, idopont, ar, kedvezmenyes_ar, max_letszam) values
    (w_mez, timestamptz '2026-12-12 15:00+01', 18900, 15900, 12) returning id into i_mez2;  -- akciós

  -- ===================== FOGLALÁSOK (vegyesen) =====================
  -- Kovászos 05-17 (MÚLT) — élő 5/8 + 1 lemondott
  insert into public.bookings (idopont_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (i_kov1, 'Kiss Anna',     'anna.kiss@example.com',    '+36301112233', 2, null, 'jovahagyott', timestamptz '2026-04-03 08:45+02'),
    (i_kov1, 'Nagy Béla',     'bela.nagy@example.com',    '+36302223344', 3, 'Ketten kezdők vagyunk.', 'jovahagyott', timestamptz '2026-04-06 19:20+02'),
    (i_kov1, 'Szabó Dóra',    'dora.szabo@example.com',   '+36304445566', 2, 'Közbejött valami.', 'lemondott', timestamptz '2026-04-18 21:30+02');

  -- Kovászos 06-14 (MÚLT) — 6/8
  insert into public.bookings (idopont_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (i_kov2, 'Kovács Emese',  'emese.kovacs@example.com', '+36303334455', 4, null, 'jovahagyott', timestamptz '2026-05-09 12:05+02'),
    (i_kov2, 'Tóth Gábor',    'gabor.toth@example.com',   '+36305556677', 2, null, 'jovahagyott', timestamptz '2026-05-20 10:15+02');

  -- Kovászos 08-16 (JÖVŐ) — 5/8 (vegyes: 1 jóváhagyott + vár)
  insert into public.bookings (idopont_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (i_kov3, 'Molnár József', 'jozsef.molnar@example.com','+36202234502', 2, null, 'jovahagyott', timestamptz '2026-07-05 07:50+02'),
    (i_kov3, 'Németh Klára',  'klara.nemeth@example.com', '+36203334503', 3, 'Ajándékutalvánnyal fizetnék.', 'jovahagyasra_var', timestamptz '2026-07-08 22:15+02');

  -- Kovászos 08-30 (JÖVŐ, drágább) — 1/8
  insert into public.bookings (idopont_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (i_kov4, 'Papp Levente',  'levente.papp@example.com', '+36204445504', 1, null, 'jovahagyasra_var', timestamptz '2026-07-10 13:40+02');

  -- Kovászos 09-13 (JÖVŐ, akciós) — 6/8
  insert into public.bookings (idopont_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (i_kov5, 'Varga Máté',    'mate.varga@example.com',   '+36207778899', 4, 'Akciós áron jönnénk.', 'jovahagyasra_var', timestamptz '2026-07-14 09:00+02'),
    (i_kov5, 'Balogh Rita',   'rita.balogh@example.com',  '+36208889900', 2, null, 'jovahagyasra_var', timestamptz '2026-07-15 14:25+02');

  -- Kovászos 10-11 (JÖVŐ) — 2/10
  insert into public.bookings (idopont_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (i_kov6, 'Fekete Ádám',   'adam.fekete@example.com',  '+36309990011', 2, null, 'jovahagyasra_var', timestamptz '2026-07-22 20:10+02');

  -- Pizza 06-21 (MÚLT) — élő 6/10 + 1 lemondott
  insert into public.bookings (idopont_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (i_piz1, 'Horváth Fanni', 'fanni.horvath@example.com','+36306667788', 4, 'Céges csapatépítő.', 'jovahagyott', timestamptz '2026-05-19 09:00+02'),
    (i_piz1, 'Simon Lilla',   'lilla.simon@example.com',  '+36201234501', 2, null, 'jovahagyott', timestamptz '2026-06-01 14:25+02'),
    (i_piz1, 'Oláh Bence',    'bence.olah@example.com',   '+36206667506', 3, 'Betegség miatt lemondom.', 'lemondott', timestamptz '2026-06-05 20:10+02');

  -- Pizza 08-22 (JÖVŐ) — 6/10
  insert into public.bookings (idopont_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (i_piz2, 'Takács Mónika', 'monika.takacs@example.com','+36205556505', 4, 'Gluténérzékeny van köztünk.', 'jovahagyasra_var', timestamptz '2026-07-12 09:30+02'),
    (i_piz2, 'Fodor Zsófia',  'zsofia.fodor@example.com', '+36207778507', 2, null, 'jovahagyasra_var', timestamptz '2026-07-17 20:45+02');

  -- Pizza 09-05 (JÖVŐ, drágább) — 3/10
  insert into public.bookings (idopont_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (i_piz3, 'Juhász Péter',  'peter.juhasz@example.com', '+36208889508', 3, null, 'jovahagyasra_var', timestamptz '2026-07-19 08:20+02');

  -- Pizza 09-19 (JÖVŐ, akciós) — 4/10
  insert into public.bookings (idopont_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (i_piz4, 'Katona Eszter', 'eszter.katona@example.com','+36209990509', 2, null, 'jovahagyasra_var', timestamptz '2026-07-21 15:55+02'),
    (i_piz4, 'Halász Tamás',  'tamas.halasz@example.com', '+36301230510', 2, null, 'jovahagyasra_var', timestamptz '2026-07-23 19:10+02');

  -- Cipó 08-23 (JÖVŐ, akciós) — 6/6 → BETELT
  insert into public.bookings (idopont_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (i_cip1, 'Pintér Vivien', 'vivien.pinter@example.com','+36301230511', 2, null, 'jovahagyasra_var', timestamptz '2026-07-25 10:35+02'),
    (i_cip1, 'Székely Dániel','daniel.szekely@example.com','+36301230512', 2, null, 'jovahagyasra_var', timestamptz '2026-07-26 21:00+02'),
    (i_cip1, 'Lakatos Ede',   'ede.lakatos@example.com',  '+36301230513', 2, 'Hárman jönnénk, de csak 2 fér — 2 főt kérek.', 'jovahagyasra_var', timestamptz '2026-07-28 12:10+02');

  -- Cipó 09-20 (JÖVŐ) — 2/6
  insert into public.bookings (idopont_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (i_cip2, 'Orbán Kata',    'kata.orban@example.com',   '+36301230514', 2, null, 'jovahagyasra_var', timestamptz '2026-07-29 09:40+02');

  -- Sütőtök 10-10 (JÖVŐ) — 3/12
  insert into public.bookings (idopont_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (i_sut1, 'Farkas Nóra',   'nora.farkas@example.com',  '+36301230515', 2, null, 'jovahagyasra_var', timestamptz '2026-07-30 10:00+02'),
    (i_sut1, 'Bíró Ádám',     'adam.biro@example.com',    '+36301230516', 1, null, 'jovahagyasra_var', timestamptz '2026-07-31 18:20+02');

  -- Mézeskalács 12-12 (JÖVŐ, akciós) — 3/12
  insert into public.bookings (idopont_id, nev, email, telefon, letszam, megjegyzes, statusz, created_at) values
    (i_mez2, 'Gál Petra',     'petra.gal@example.com',    '+36301230517', 3, 'Gyerekekkel jönnénk.', 'jovahagyasra_var', timestamptz '2026-08-01 11:05+02');

  -- (Foglalás nélkül marad: Kovászos egy jövője már betöltött, Cipó 10-18, Mézeskalács 11-28 → üres időpontok a valósághűségért.)

end $$;

-- =====================================================================
--  ELLENŐRZÉS
-- =====================================================================

-- Program × időpont időrendben (a hamarosan-érkezők a végén):
select cim,
       coalesce(to_char(idopont, 'YYYY-MM-DD HH24:MI'), '(nincs időpont)') as idopont,
       program_statusz, idopont_statusz,
       coalesce(kedvezmenyes_ar, ar) as ar, max_letszam, szabad_helyek
from public.programok
order by idopont nulls last, cim;

-- Foglalások program + időpont + státusz bontásban (db + fő):
select w.cim,
       coalesce(to_char(i.idopont, 'YYYY-MM-DD'), '—') as nap,
       b.statusz,
       count(*)                    as foglalasok,
       coalesce(sum(b.letszam), 0) as fo
from public.bookings b
join public.idopontok i on i.id = b.idopont_id
join public.workshops w on w.id = i.workshop_id
group by w.cim, i.idopont, b.statusz
order by i.idopont nulls last, w.cim, b.statusz;
