-- =====================================================================
--  DEV-MIGRÁCIÓ: FOGLALÁS ÁTMENETI FELFÜGGESZTÉSE (szünet)
--
--  Két kapcsoló:
--    • program-szintű:  workshops.foglalas_felfuggesztve  (igen/nem)
--    • globális:        settings.foglalas_szunet          (igen/nem, „minden foglalás")
--
--  Ha valamelyik be van kapcsolva, a PUBLIKUS (anon) foglalást a trigger
--  elutasítja; az admin továbbra is rögzíthet kézzel. A főoldalon a program
--  „Foglalás átmenetileg felfüggesztve” jelzést kap.
--
--  A végleges séma a db/01-schema.sql-ben van; ez a meglévő dev-DB patch-e.
-- =====================================================================

alter table public.workshops
  add column if not exists foglalas_felfuggesztve boolean not null default false;
alter table public.settings
  add column if not exists foglalas_szunet boolean not null default false;

-- --- programok nézet újra (a foglalas_felfuggesztve mezővel) ---
drop view if exists public.programok;
create view public.programok as
select
  w.id                as workshop_id,
  w.cim, w.rovid_leiras, w.leiras, w.eloado, w.varhato_idotartam, w.foto_url,
  w.archivalt, w.foglalas_felfuggesztve,
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
grant select on public.programok to anon, authenticated;

-- --- túlfoglalás-trigger újra (szünet-ellenőrzéssel) ---
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
  v_felfugg      boolean;
  v_szunet       boolean;
  v_foglalt      integer;
begin
  if new.statusz in ('jovahagyasra_var','jovahagyott') then
    select i.max_letszam, i.statusz, i.idopont, w.statusz, w.archivalt, w.foglalas_felfuggesztve
      into v_max, v_ido_statusz, v_idopont, v_prog_statusz, v_archivalt, v_felfugg
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

    -- Szünet: a PUBLIKUS (anon) foglalást felfüggesztjük (program-szintű vagy globális).
    select foglalas_szunet into v_szunet from public.settings where id = 1;
    if tg_op = 'INSERT' and coalesce(auth.role(), '') = 'anon'
       and (coalesce(v_felfugg, false) or coalesce(v_szunet, false)) then
      raise exception 'A foglalás erre a programra jelenleg átmenetileg szünetel.';
    end if;

    -- Publikus (anon) foglalás NEM mehet MÚLTBÉLI időpontra.
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

-- Ellenőrzés
select
  (select count(*) from public.workshops where foglalas_felfuggesztve) as felfuggesztett_programok,
  (select foglalas_szunet from public.settings where id = 1)           as globalis_szunet;
