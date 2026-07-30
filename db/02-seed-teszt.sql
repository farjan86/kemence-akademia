-- =====================================================================
--  Kemence Akadémia — TESZT adatok (ideiglenes)
--  Célja: kipróbálni, hogy a séma működik (szabad helyek, túlfoglalás).
--  ⚠️ Ez teszt-adat — élesítés előtt töröljük (lásd a fájl alján).
-- =====================================================================

-- ---- Néhány minta-program ----
insert into public.workshops
  (cim, leiras, ar, kedvezmenyes_ar, idopont, varhato_idotartam, max_letszam, statusz)
values
  ('Nápolyi pizza workshop',
   'Igazi leopárdfoltos nápolyi pizza, kézzel nyújtva, a kemence parazsánál sütve.',
   18900, null, timestamptz '2026-08-15 10:00', '~4 óra', 8, 'aktiv'),

  ('Burek workshop',
   'Vékonyra húzott réteslap, sós és édes töltelékkel — a Balkán kedvence.',
   16900, 13900, timestamptz '2026-08-22 14:00', '~3 óra', 8, 'aktiv'),   -- akciós ár!

  ('Kovászos kenyér workshop',
   'Saját kovásszal, ropogós héjjal, lyukacsos béllel. A kovászt hazaviszed.',
   17900, null, timestamptz '2026-08-29 10:00', '~5 óra', 6, 'aktiv'),

  ('Csili szósz workshop',
   'Pörkölt paprikából, lassan főzve — a saját erősséged, a saját üvegedben.',
   14900, null, timestamptz '2026-09-05 16:00', null, 10, 'aktiv'),

  ('Bejgli workshop',
   'Diós és mákos, márványos metszettel. Ünnepi szezonban indul.',
   null, null, null, null, null, 'hamarosan');                            -- "hamarosan": csak cím+leírás

-- ---- Egy-két teszt-foglalás (a pizza workshopra) ----
-- (A SQL Editorban a szabályok az adminként futnak, ezért ide közvetlenül írhatunk.)
insert into public.bookings (workshop_id, nev, email, telefon, letszam, statusz)
select id, 'Teszt Anna', 'anna@example.com', '+36301234567', 3, 'jovahagyasra_var'
from public.workshops where cim = 'Nápolyi pizza workshop';

insert into public.bookings (workshop_id, nev, email, telefon, letszam, statusz)
select id, 'Teszt Béla', 'bela@example.com', '+36307654321', 2, 'jovahagyott'
from public.workshops where cim = 'Nápolyi pizza workshop';

-- =====================================================================
--  ELLENŐRZÉS — futtasd le ezeket külön, és nézd meg az eredményt:
-- =====================================================================

-- 1) A publikus programlista a szabad helyekkel.
--    A pizzánál 8 - (3+2) = 3 szabad helyet kell mutatnia.
--    A "hamarosan" bejglinél szabad_helyek = 0 (nincs max létszám).
select cim, statusz, max_letszam, szabad_helyek, ar, kedvezmenyes_ar
from public.programok
order by idopont nulls last;

-- 2) Csak a pizza foglalt helyei (segédfüggvény):
-- select public.foglalt_helyek(id) from public.workshops where cim = 'Nápolyi pizza workshop';

-- 3) TÚLFOGLALÁS PRÓBA — ezt SZÁNDÉKOSAN el kell utasítania a triggernek.
--    A pizzán már csak 3 hely szabad; 5 főt kérünk → hibát kell dobnia:
-- insert into public.bookings (workshop_id, nev, email, telefon, letszam, statusz)
-- select id, 'Túl Sok', 'tul@example.com', '+36300000000', 5, 'jovahagyasra_var'
-- from public.workshops where cim = 'Nápolyi pizza workshop';
--    -> Elvárt hiba: "Nincs elég szabad hely (3 szabad)."

-- =====================================================================
--  TAKARÍTÁS — ha végeztél a teszteléssel, ezzel törölhető minden teszt-adat:
-- =====================================================================
-- delete from public.bookings;
-- delete from public.workshops;
