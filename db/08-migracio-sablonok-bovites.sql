-- =====================================================================
--  Migráció: két új e-mail sablon — visszaigazolás (vendég) + csapat-értesítő.
--  Engedélyezi a 'csapat_ertesito' típust is. Futtasd a meglévő DB-n.
--  (A 01-schema.sql már tartalmazza ezeket.)
-- =====================================================================

-- A 'csapat_ertesito' típus engedélyezése a check-szabályban
alter table public.email_sablonok drop constraint if exists email_sablonok_tipus_check;
alter table public.email_sablonok add constraint email_sablonok_tipus_chk
  check (tipus in ('jovahagyas','elutasitas','lemondas','visszaigazolas','csapat_ertesito','emlekezteto'));

-- A két új sablon (behelyettesíthető mezők: {nev} {email} {telefon} {program} {idopont} {letszam} {azonosito})
insert into public.email_sablonok (tipus, targy, torzs) values
('visszaigazolas',
 'Foglalásod megkaptuk – Kemence Akadémia ({azonosito})',
 E'Kedves {nev}!\n\nKöszönjük a foglalásod! A(z) {program} ({idopont}) programra {letszam} fő jelentkezésedet rögzítettük.\n\nA foglalás jelenleg jóváhagyásra vár. Hamarosan felvesszük veled a kapcsolatot az előre utalás egyeztetéséhez, és a foglalást annak beérkezése után hagyjuk jóvá.\n\nFoglalási azonosító: {azonosito}\n\nÜdvözlettel,\nKemence Akadémia'),
('csapat_ertesito',
 'Új foglalás – {program} ({azonosito})',
 E'Új foglalás érkezett.\n\nAzonosító: {azonosito}\nProgram: {program}\nIdőpont: {idopont}\nLétszám: {letszam} fő\n\nFoglaló: {nev}\nE-mail: {email}\nTelefon: {telefon}\n\nA foglalás jóváhagyásra vár az admin felületen.')
on conflict (tipus) do nothing;
