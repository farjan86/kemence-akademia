-- =====================================================================
--  Migráció: LÁTOGATÁS-SZÁMLÁLÓ (egyszerű, globális)
--
--  Egy egysoros tábla tárolja az összes látogatás számát. A publikus oldal
--  a `latogatas_rogzites()` függvénnyel növeli (böngészőnként 6 óránként max
--  egyszer — ezt a kliens localStorage-ban kezeli), és a `latogatas_szam()`
--  függvénnyel olvassa. A tábla RLS mögött van; közvetlenül nem írható/olvasható,
--  csak a SECURITY DEFINER függvényeken keresztül.
--
--  A 01-schema.sql már tartalmazza ezt (üres telepítésnél ott van).
-- =====================================================================

create table if not exists public.oldal_statisztika (
  id           integer primary key default 1 check (id = 1),
  latogatasok  bigint not null default 0,
  updated_at   timestamptz not null default now()
);

insert into public.oldal_statisztika (id, latogatasok)
values (1, 0) on conflict (id) do nothing;

alter table public.oldal_statisztika enable row level security;
-- Szándékosan NINCS közvetlen policy — csak a lenti függvényeken át érhető el.

-- Új látogatás rögzítése: növel eggyel, és visszaadja az új összeget.
create or replace function public.latogatas_rogzites()
returns bigint
language sql
security definer
set search_path = public
as $$
  update public.oldal_statisztika
     set latogatasok = latogatasok + 1, updated_at = now()
   where id = 1
  returning latogatasok;
$$;

-- Aktuális látogatásszám (nem növel).
create or replace function public.latogatas_szam()
returns bigint
language sql
security definer
set search_path = public
as $$
  select latogatasok from public.oldal_statisztika where id = 1;
$$;

grant execute on function public.latogatas_rogzites() to anon, authenticated;
grant execute on function public.latogatas_szam()     to anon, authenticated;
