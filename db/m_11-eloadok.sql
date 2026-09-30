-- =====================================================================
--  DEV-MIGRÁCIÓ: Előadóink
--
--  Két új tábla:
--    • eloadok          — a csapattagok (név, bemutatkozás, fotó, sorrend, rejtett)
--    • program_eloadok  — melyik program(ok)hoz melyik előadó tartozik
--
--  A programok NÉZET kiegészül az előadók listájával, hogy a főoldali
--  kártya egy lekérdezésből megkapja a kattintható neveket.
--
--  SZABÁLYOK (a terv szerint — docs/eloadoink-terv.md):
--    • Előadó csak akkor törölhető, ha egyetlen programhoz sincs kötve
--      (ezt az `on delete restrict` az adatbázisban is betartatja).
--    • Elrejteni bármikor lehet — a rejtés csak a Rólunk névsort érinti.
--
--  ⚠️ A RÉGI `workshops.eloado` SZABAD SZÖVEGES OSZLOP TÖRLŐDIK, a benne lévő
--  nevekkel együtt. Ez szándékos: a neveket NEM vesszük át automatikusan —
--  az előadókat az adminban, az „Előadóink" fülön kell felvenni, majd a
--  programoknál bepipálni. Így mindenkinek lesz bemutatkozása és képe is.
--  (Éles rendszer még nincs; a fejlesztői és a demó adatban vállalható.)
--
--  HOL FUTTASD: a MEGLÉVŐ adatbázisokban — fejlesztői ÉS demó projekt.
--  Új (éles) projekthez nem kell: a db/01-schema.sql már tartalmazza.
--  Újrafuttatható.
-- =====================================================================

-- ---------------------------------------------------------------------
--  1) Táblák
-- ---------------------------------------------------------------------
create table if not exists public.eloadok (
  id            uuid primary key default gen_random_uuid(),
  nev           text not null check (char_length(nev) <= 100),
  bemutatkozas  text,
  foto_url      text,                               -- a PUBLIKUS program-fotok bucketben
  sorrend       integer not null default 0,         -- kézi sorrend (admin húzással)
  rejtett       boolean not null default false,     -- true = nem látszik a Rólunk névsorban
  created_at    timestamptz not null default now()
);
create index if not exists eloadok_rejtett_idx on public.eloadok (rejtett);
create index if not exists eloadok_sorrend_idx on public.eloadok (sorrend);

create table if not exists public.program_eloadok (
  workshop_id uuid not null references public.workshops(id) on delete cascade,
  eloado_id   uuid not null references public.eloadok(id)   on delete restrict,
  primary key (workshop_id, eloado_id)
);
create index if not exists program_eloadok_eloado_idx on public.program_eloadok (eloado_id);

-- ---------------------------------------------------------------------
--  2) Jogosultság (RLS) — publikus tartalom: bárki olvashatja, admin írja
-- ---------------------------------------------------------------------
alter table public.eloadok         enable row level security;
alter table public.program_eloadok enable row level security;

drop policy if exists eloadok_read on public.eloadok;
create policy eloadok_read on public.eloadok
  for select using (true);

drop policy if exists eloadok_admin on public.eloadok;
create policy eloadok_admin on public.eloadok
  for all to authenticated
  using (auth.uid() is not null) with check (auth.uid() is not null);

drop policy if exists program_eloadok_read on public.program_eloadok;
create policy program_eloadok_read on public.program_eloadok
  for select using (true);

drop policy if exists program_eloadok_admin on public.program_eloadok;
create policy program_eloadok_admin on public.program_eloadok
  for all to authenticated
  using (auth.uid() is not null) with check (auth.uid() is not null);

-- ---------------------------------------------------------------------
--  3) A régi szöveges mező elhagyása
--     A nézet hivatkozik az oszlopra, ezért előbb a nézetet ejtjük el.
--     A régi nevek ezzel elvesznek — az előadókat az adminban vesszük fel.
-- ---------------------------------------------------------------------
drop view if exists public.programok;
alter table public.workshops drop column if exists eloado;

-- ---------------------------------------------------------------------
--  4) programok nézet — az előadók listájával
--     Az `eloadok` mező JSON tömb: [{id, nev, rejtett}, …] sorrend szerint.
--     Ha a programhoz nincs előadó, NULL — a kártyán ilyenkor nincs „Előadó:" sor.
-- ---------------------------------------------------------------------
create view public.programok as
select
  w.id                as workshop_id,
  w.cim, w.rovid_leiras, w.leiras, w.varhato_idotartam, w.foto_url,
  w.archivalt, w.foglalas_felfuggesztve, w.sorrend,
  w.statusz           as program_statusz,
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

-- ---------------------------------------------------------------------
--  5) Ellenőrzés
-- ---------------------------------------------------------------------
select
  (select count(*) from public.eloadok)         as eloadok_db,
  (select count(*) from public.program_eloadok) as kapcsolatok_db;

-- Melyik programnál kik az előadók?
select w.cim,
       coalesce(string_agg(e.nev, ', ' order by e.sorrend), '—') as eloadok
from public.workshops w
left join public.program_eloadok pe on pe.workshop_id = w.id
left join public.eloadok e on e.id = pe.eloado_id
group by w.cim
order by w.cim;
