-- =====================================================================
--  Migráció: RÖVID leírás mező a programokhoz
--  A workshops.leiras marad a RÉSZLETES leírás (a „Részletek" ablakban),
--  az új workshops.rovid_leiras a KÁRTYÁN megjelenő rövid szöveg.
--  Futtasd a már meglévő (dev) DB-n. Friss telepítésnél a 01-schema.sql
--  már tartalmazza, ezt akkor nem kell futtatni.
-- =====================================================================

alter table public.workshops
  add column if not exists rovid_leiras text;

-- a részletes leírás mostantól OPCIONÁLIS
alter table public.workshops
  alter column leiras drop not null;

-- A publikus nézet újraépítése az új mezővel
drop view if exists public.programok;
create view public.programok as
select
  w.id, w.cim, w.rovid_leiras, w.leiras, w.ar, w.kedvezmenyes_ar, w.idopont,
  w.varhato_idotartam, w.foto_url, w.statusz, w.max_letszam, w.archivalt,
  greatest(coalesce(w.max_letszam,0) - public.foglalt_helyek(w.id), 0) as szabad_helyek
from public.workshops w;
