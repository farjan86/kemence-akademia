-- =====================================================================
--  DEV-MIGRÁCIÓ: TÖBB IDŐPONT egy programhoz
--
--  A meglévő (üres) dev-adatbázis sémáját alakítja át az új modellre:
--    • ÚJ  public.idopontok tábla (idopont + ar + kedvezmenyes_ar + max_letszam + statusz)
--    • bookings.workshop_id  →  bookings.idopont_id
--    • workshops: ar/kedvezmenyes_ar/idopont/max_letszam OSZLOPOK ELtávolítása,
--      + ÚJ eloado oszlop, + statusz check szűkítése ('aktiv','hamarosan')
--    • foglalt_helyek(), programok nézet, túlfoglalás-trigger, RLS átírása időpontra
--
--  ⚠️ FELTÉTELEZI, hogy a bookings ÉS workshops ÜRES (előbb futtasd:
--     db/t_reset-ures-allapot.sql). Adatot NEM ment át — dev-only.
--
--  Ez IDEIGLENES script: a végleges séma a db/01-schema.sql-ben van; miután
--  a dev-DB átállt, ez a fájl törölhető.
-- =====================================================================

-- --- 0) Biztonsági ellenőrzés: ne fusson, ha van adat ---
do $$
begin
  if exists (select 1 from public.bookings) then
    raise exception 'A bookings tábla NEM üres — előbb futtasd a t_reset-ures-allapot.sql-t.';
  end if;
end $$;

-- --- 1) Függő objektumok eldobása (újra létrehozzuk lentebb) ---
drop trigger if exists trg_szabad_hely on public.bookings;
drop function if exists public.ellenoriz_szabad_hely() cascade;
drop view if exists public.programok;
drop function if exists public.foglalt_helyek(uuid);

-- --- 2) bookings: régi workshop_id oszlop eltávolítása ---
alter table public.bookings drop constraint if exists bookings_workshop_id_fkey;
drop index if exists public.bookings_workshop_idx;
alter table public.bookings drop column if exists workshop_id;

-- --- 3) workshops: időpont-szintű mezők eltávolítása, eloado hozzáadása ---
alter table public.workshops
  drop constraint if exists kedvezmeny_kisebb,
  drop constraint if exists aktiv_kotelezo,
  drop constraint if exists letszam_pozitiv;

alter table public.workshops
  drop column if exists ar,
  drop column if exists kedvezmenyes_ar,
  drop column if exists idopont,
  drop column if exists max_letszam;

alter table public.workshops
  add column if not exists eloado text;

-- statusz check szűkítése 'aktiv'/'hamarosan'-ra (a régi 'elmaradt' most időpont-szintű).
-- Üres tábla → biztonságosan cserélhető a constraint.
alter table public.workshops drop constraint if exists workshops_statusz_check;
alter table public.workshops
  add constraint workshops_statusz_check check (statusz in ('aktiv','hamarosan'));

-- --- 4) ÚJ idopontok tábla ---
create table if not exists public.idopontok (
  id                 uuid primary key default gen_random_uuid(),
  workshop_id        uuid not null references public.workshops(id) on delete cascade,
  idopont            timestamptz not null,
  ar                 integer not null,
  kedvezmenyes_ar    integer,
  max_letszam        integer not null,
  statusz            text not null default 'aktiv'
                       check (statusz in ('aktiv','elmaradt')),
  created_at         timestamptz not null default now(),
  constraint idopont_kedvezmeny_kisebb
    check (kedvezmenyes_ar is null or kedvezmenyes_ar < ar),
  constraint idopont_letszam_pozitiv
    check (max_letszam > 0)
);

-- --- 5) bookings: ÚJ idopont_id oszlop + FK (üres tábla → set not null OK) ---
alter table public.bookings add column if not exists idopont_id uuid;
alter table public.bookings
  add constraint bookings_idopont_id_fkey foreign key (idopont_id)
  references public.idopontok(id) on delete restrict;
alter table public.bookings alter column idopont_id set not null;

-- --- 6) Indexek ---
create index if not exists idopontok_workshop_idx on public.idopontok (workshop_id);
create index if not exists idopontok_idopont_idx   on public.idopontok (idopont);
create index if not exists bookings_idopont_idx    on public.bookings (idopont_id);

-- --- 7) foglalt_helyek(uuid) — most IDŐPONTRA ---
create or replace function public.foglalt_helyek(p_idopont uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(letszam), 0)::int
  from public.bookings
  where idopont_id = p_idopont
    and statusz in ('jovahagyasra_var','jovahagyott');
$$;

-- --- 8) programok nézet — program × időpont (LEFT JOIN a 'hamarosan'-hoz) ---
create view public.programok as
select
  w.id                as workshop_id,
  w.cim, w.rovid_leiras, w.leiras, w.eloado, w.varhato_idotartam, w.foto_url,
  w.archivalt,
  w.statusz           as program_statusz,
  i.id                as idopont_id,
  i.idopont,
  i.ar, i.kedvezmenyes_ar, i.max_letszam,
  i.statusz           as idopont_statusz,
  case when i.id is null then null
       else greatest(coalesce(i.max_letszam,0) - public.foglalt_helyek(i.id), 0)
  end                 as szabad_helyek
from public.workshops w
left join public.idopontok i on i.workshop_id = w.id;

-- --- 9) túlfoglalás-trigger — időpont-szinten ---
create or replace function public.ellenoriz_szabad_hely()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_max          integer;
  v_ido_statusz  text;
  v_idopont      timestamptz;
  v_prog_statusz text;
  v_archivalt    boolean;
  v_foglalt      integer;
begin
  if new.statusz in ('jovahagyasra_var','jovahagyott') then
    select i.max_letszam, i.statusz, i.idopont, w.statusz, w.archivalt
      into v_max, v_ido_statusz, v_idopont, v_prog_statusz, v_archivalt
    from public.idopontok i
    join public.workshops w on w.id = i.workshop_id
    where i.id = new.idopont_id;

    if not found then
      raise exception 'Ismeretlen időpont.';
    end if;

    if v_ido_statusz = 'elmaradt' then
      raise exception 'Ez az időpont elmaradt, nem foglalható.';
    end if;

    if v_prog_statusz is distinct from 'aktiv' or coalesce(v_archivalt, false) then
      raise exception 'Erre a programra nem lehet foglalni (nem aktív).';
    end if;

    if tg_op = 'INSERT'
       and coalesce(auth.role(), '') = 'anon'
       and v_idopont is not null
       and (v_idopont at time zone 'Europe/Budapest')::date
           < (now()      at time zone 'Europe/Budapest')::date then
      raise exception 'Erre az időpontra már nem lehet foglalni (lezárult).';
    end if;

    select coalesce(sum(letszam),0) into v_foglalt
    from public.bookings
    where idopont_id = new.idopont_id
      and statusz in ('jovahagyasra_var','jovahagyott')
      and id <> new.id;

    if v_foglalt + new.letszam > coalesce(v_max,0) then
      raise exception 'Nincs elég szabad hely (% szabad).',
        greatest(coalesce(v_max,0) - v_foglalt, 0);
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_szabad_hely on public.bookings;
create trigger trg_szabad_hely
  before insert or update on public.bookings
  for each row execute function public.ellenoriz_szabad_hely();

-- --- 10) RLS az ÚJ idopontok táblára + grantok ---
alter table public.idopontok enable row level security;

drop policy if exists idopontok_read on public.idopontok;
create policy idopontok_read on public.idopontok
  for select using (true);

drop policy if exists idopontok_admin on public.idopontok;
create policy idopontok_admin on public.idopontok
  for all to authenticated
  using (auth.uid() is not null) with check (auth.uid() is not null);

grant select  on public.programok       to anon, authenticated;
grant execute on function public.foglalt_helyek(uuid) to anon, authenticated;

-- =====================================================================
--  Ellenőrzés: az új szerkezet
-- =====================================================================
select 'idopontok tabla' as mit, count(*) as db from public.idopontok
union all
select 'programok nezet sorai', count(*) from public.programok;
