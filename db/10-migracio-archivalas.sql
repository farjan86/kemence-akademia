-- =====================================================================
--  Migráció: program-archiválás + program-elmaradás.
--    - workshops.archivalt (a program nem jelenik meg a főoldalon)
--    - bookings.statusz: új 'elmaradt' érték (program elmaradása miatt)
--    - email_sablonok: 'program_elmarad' típus + sablon
--    - programok nézet: archivalt oszlop, hogy szűrhető legyen
--  Futtasd a meglévő DB-n. (A 01-schema.sql már tartalmazza ezeket.)
-- =====================================================================

-- 1) Archivált flag a programokon
alter table public.workshops add column if not exists archivalt boolean not null default false;
create index if not exists workshops_archivalt_idx on public.workshops (archivalt);

-- 2) A publikus nézet lássa az archivalt mezőt (a szűréshez).
--    Eldobjuk + újra létrehozzuk (create-or-replace nem tud középre oszlopot szúrni).
drop view if exists public.programok;
create view public.programok as
select
  w.id, w.cim, w.leiras, w.ar, w.kedvezmenyes_ar, w.idopont,
  w.varhato_idotartam, w.foto_url, w.statusz, w.max_letszam, w.archivalt,
  greatest(coalesce(w.max_letszam,0) - public.foglalt_helyek(w.id), 0) as szabad_helyek
from public.workshops w;
grant select on public.programok to anon, authenticated;

-- 3) Foglalás státuszok bővítése az 'elmaradt' értékkel
alter table public.bookings drop constraint if exists bookings_statusz_check;
alter table public.bookings drop constraint if exists bookings_statusz_chk;
alter table public.bookings add constraint bookings_statusz_chk
  check (statusz in ('jovahagyasra_var','jovahagyott','elutasitott','lemondott','elmaradt'));

-- 4) 'program_elmarad' e-mail sablon
alter table public.email_sablonok drop constraint if exists email_sablonok_tipus_check;
alter table public.email_sablonok drop constraint if exists email_sablonok_tipus_chk;
alter table public.email_sablonok add constraint email_sablonok_tipus_chk
  check (tipus in ('jovahagyas','elutasitas','lemondas','visszaigazolas','csapat_ertesito','program_elmarad','emlekezteto'));

insert into public.email_sablonok (tipus, targy, torzs) values
('program_elmarad',
 'A program elmarad – Kemence Akadémia ({azonosito})',
 E'Kedves {nev}!\n\nSajnálattal értesítünk, hogy a(z) {program} ({idopont}) program sajnos elmarad.\n\nElnézést kérünk a kellemetlenségért. Ha kérdésed van, keress minket bizalommal.\n\nÜdvözlettel,\nKemence Akadémia')
on conflict (tipus) do nothing;
