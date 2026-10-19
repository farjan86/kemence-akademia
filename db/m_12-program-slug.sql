-- =====================================================================
--  DEV-MIGRÁCIÓ: megosztható program-link (slug)
--
--  Minden programhoz tartozik egy rövid, olvasható azonosító, amiből a
--  megosztható link áll össze:
--      https://kemence-akademia.xyz/?program=kortars-napolyi-pizza-workshop
--
--  MŰKÖDÉS
--    • A `slug` a program CÍMÉBŐL képződik, BESZÚRÁSKOR, automatikusan.
--    • ÁTNEVEZÉSKOR NEM VÁLTOZIK — különben minden korábban megosztott
--      link némán elromlana. (Ezért a trigger csak `before insert`.)
--    • Egyedi: ütközésnél -2, -3, … toldalék.
--    • Az adminban NINCS hozzá mező: a csapatnak nincs vele teendője.
--
--  HOL FUTTASD: a MEGLÉVŐ adatbázisokban — fejlesztői, demó ÉS éles.
--  Új projekthez nem kell: a db/01-schema.sql már tartalmazza.
--  Újrafuttatható.
-- =====================================================================

-- ---------------------------------------------------------------------
--  BIZTONSÁG: az egész migráció EGY tranzakcióban fut.
--  Ha bármelyik lépés hibára futna, a teljes migráció visszagördül —
--  az adatbázis pontosan abban az állapotban marad, mint előtte.
--  (A nézet eldobása és újraépítése is így atomi: a publikus oldal nem
--  találkozhat „eltűnt" nézettel, legfeljebb pár ezredmásodpercet vár.)
-- ---------------------------------------------------------------------
begin;

-- ---------------------------------------------------------------------
--  1) Oszlop
-- ---------------------------------------------------------------------
alter table public.workshops add column if not exists slug text;

-- ---------------------------------------------------------------------
--  2) Slug képzése a címből
--     „Kortárs Nápolyi Pizza Workshop" → „kortars-napolyi-pizza-workshop"
-- ---------------------------------------------------------------------
create or replace function public.slug_keszit(szoveg text)
returns text
language plpgsql
immutable
as $$
declare
  s text;
begin
  -- Magyar ékezetek átírása, a KIS- és NAGYBETŰS párral együtt, még a
  -- kisbetűsítés előtt: így nem függ az adatbázis nyelvi beállításától,
  -- hogy a lower() ismeri-e az „Á"-t. (A from és a to AZONOS karakterszámú!)
  s := translate(coalesce(szoveg, ''), 'áéíóöőúüűÁÉÍÓÖŐÚÜŰ', 'aeiooouuuAEIOOOUUU');
  s := lower(s);
  -- minden egyéb (szóköz, írásjel, idegen betű) → kötőjel
  s := regexp_replace(s, '[^a-z0-9]+', '-', 'g');
  s := btrim(s, '-');
  -- Legfeljebb 80 karakter, de nem vágunk szó közepébe: ha a 80. karakter
  -- után még folytatódna a szó, a csonka utolsó szót elhagyjuk.
  if length(s) > 80 then
    if substr(s, 81, 1) = '-' then
      s := left(s, 80);                                   -- pont szóhatáron vágtunk
    else
      s := regexp_replace(left(s, 80), '-[^-]*$', '');    -- a csonka utolsó szó nélkül
    end if;
    s := btrim(s, '-');
  end if;
  return nullif(s, '');
end;
$$;

-- ---------------------------------------------------------------------
--  3) Egyediség — ütközésnél -2, -3, …
--     A `sajat_id` azért kell, hogy egy sor ne ütközzön saját magával.
-- ---------------------------------------------------------------------
create or replace function public.slug_egyedi(alap text, sajat_id uuid default null)
returns text
language plpgsql
as $$
declare
  jelolt text := alap;
  n      integer := 1;
begin
  while exists (
    select 1 from public.workshops
     where slug = jelolt
       and (sajat_id is null or id <> sajat_id)
  ) loop
    n := n + 1;
    jelolt := alap || '-' || n;
  end loop;
  return jelolt;
end;
$$;

-- ---------------------------------------------------------------------
--  4) A meglévő programok feltöltése
--     (A trigger előtt fut, hogy a régi soroknak is legyen linkje.)
-- ---------------------------------------------------------------------
do $$
declare
  r    record;
  alap text;
begin
  for r in select id, cim from public.workshops
            where slug is null or btrim(slug) = ''
            order by created_at
  loop
    alap := public.slug_keszit(r.cim);
    -- Ha a címből nem képezhető azonosító (pl. csupa írásjel), az azonosító
    -- első 8 jegye lesz a slug.
    if alap is null then
      alap := left(replace(r.id::text, '-', ''), 8);
    end if;
    update public.workshops
       set slug = public.slug_egyedi(alap, r.id)
     where id = r.id;
  end loop;
end $$;

-- ---------------------------------------------------------------------
--  5) Egyedi index (a feltöltés UTÁN)
-- ---------------------------------------------------------------------
create unique index if not exists workshops_slug_uniq on public.workshops (slug);

-- ---------------------------------------------------------------------
--  6) Trigger — CSAK beszúráskor
--     Az `update` szándékosan kimarad: a cím átírása nem ronthatja el a
--     már megosztott linkeket.
-- ---------------------------------------------------------------------
create or replace function public.trg_workshop_slug()
returns trigger
language plpgsql
as $$
declare
  alap text;
begin
  if new.slug is null or btrim(new.slug) = '' then
    alap := public.slug_keszit(new.cim);
    if alap is null then
      alap := left(replace(new.id::text, '-', ''), 8);
    end if;
    new.slug := public.slug_egyedi(alap, new.id);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_workshop_slug on public.workshops;
create trigger trg_workshop_slug
  before insert on public.workshops
  for each row execute function public.trg_workshop_slug();

-- ---------------------------------------------------------------------
--  7) A publikus nézet kiegészítése a slug oszloppal
-- ---------------------------------------------------------------------
drop view if exists public.programok;
create view public.programok as
select
  w.id                as workshop_id,
  w.cim, w.slug, w.rovid_leiras, w.leiras, w.varhato_idotartam, w.foto_url,
  w.archivalt, w.foglalas_felfuggesztve, w.sorrend,
  w.statusz           as program_statusz,     -- 'aktiv' / 'hamarosan'
  (select json_agg(json_build_object('id', e.id, 'nev', e.nev, 'rejtett', e.rejtett)
                   order by e.sorrend, e.nev)
     from public.program_eloadok pe
     join public.eloadok e on e.id = pe.eloado_id
    where pe.workshop_id = w.id)            as eloadok,
  i.id                as idopont_id,
  i.idopont,
  i.ar, i.kedvezmenyes_ar, i.max_letszam,
  i.max_foglalasok, i.min_letszam,
  i.statusz           as idopont_statusz,
  case when i.id is null then null
       else greatest(coalesce(i.max_letszam,0) - public.foglalt_helyek(i.id), 0)
  end                 as szabad_helyek,
  case when i.id is null then null
       else public.foglalasok_szama(i.id)
  end                 as foglalasok_szama
from public.workshops w
left join public.idopontok i on i.workshop_id = w.id;

grant select on public.programok to anon, authenticated;

commit;

-- ---------------------------------------------------------------------
--  8) Ellenőrzés (már a lezárt tranzakció után)
-- ---------------------------------------------------------------------
select cim, slug from public.workshops order by sorrend, cim;

-- Van-e slug nélküli program? (0 sort kell adnia)
select count(*) as slug_nelkul from public.workshops where slug is null or btrim(slug) = '';
