-- =====================================================================
--  DEV-MIGRÁCIÓ: időpont foglalási korlátai (csoportos alkalom)
--
--  Két új, OPCIONÁLIS mező az idopontok-on:
--    • max_foglalasok (db)  — hány FOGLALÁS (csapat) jöhet az időpontra
--    • min_letszam    (fő)  — egy foglalás LEGALÁBB ennyi fős legyen
--  (Üresen hagyva = mostani viselkedés: korlátlan foglalás, nincs minimum.)
--
--  Lezárás (a publikus oldalon nem foglalható) — bármelyik teljesül:
--    - az élő foglalások SZÁMA elérte a max_foglalasok-ot, VAGY
--    - a szabad hely < min_letszam, VAGY
--    - betelt a max_letszam.
--  A trigger a PUBLIKUS (anon) foglalást tiltja; az admin felülbírálhatja.
--
--  A végleges séma a db/01-schema.sql-ben van; ez a meglévő dev-DB patch-e.
-- =====================================================================

alter table public.idopontok
  add column if not exists max_foglalasok integer,   -- hány foglalás jöhet (null = korlátlan)
  add column if not exists min_letszam    integer;   -- egy foglalás min. létszáma (null = nincs)

-- Épeszűség: pozitív értékek, és a minimum nem lehet nagyobb a kapacitásnál.
alter table public.idopontok drop constraint if exists idopont_max_foglalasok_pozitiv;
alter table public.idopontok add  constraint idopont_max_foglalasok_pozitiv
  check (max_foglalasok is null or max_foglalasok >= 1);
alter table public.idopontok drop constraint if exists idopont_min_letszam_ervenyes;
alter table public.idopontok add  constraint idopont_min_letszam_ervenyes
  check (min_letszam is null or (min_letszam >= 1 and min_letszam <= max_letszam));

-- --- Élő foglalások SZÁMA egy időponton (a max_foglalasok-hoz) ---
create or replace function public.foglalasok_szama(p_idopont uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int
  from public.bookings
  where idopont_id = p_idopont
    and statusz in ('jovahagyasra_var','jovahagyott');
$$;
grant execute on function public.foglalasok_szama(uuid) to anon, authenticated;

-- --- programok nézet újra (a két új mezővel + a foglalások számával) ---
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

-- --- túlfoglalás-trigger újra (min. létszám + max. foglalások ellenőrzéssel) ---
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
  v_maxfogl      integer;
  v_min          integer;
  v_foglalt      integer;
  v_fogl_szam    integer;
begin
  if new.statusz in ('jovahagyasra_var','jovahagyott') then
    select i.max_letszam, i.statusz, i.idopont, w.statusz, w.archivalt, w.foglalas_felfuggesztve,
           i.max_foglalasok, i.min_letszam
      into v_max, v_ido_statusz, v_idopont, v_prog_statusz, v_archivalt, v_felfugg,
           v_maxfogl, v_min
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

    -- Szünet (program-szintű vagy globális) — csak a publikus (anon) foglalásra.
    select foglalas_szunet into v_szunet from public.settings where id = 1;
    if tg_op = 'INSERT' and coalesce(auth.role(), '') = 'anon'
       and (coalesce(v_felfugg, false) or coalesce(v_szunet, false)) then
      raise exception 'A foglalás erre a programra jelenleg átmenetileg szünetel.';
    end if;

    -- Publikus (anon) foglalás NEM mehet MÚLTBÉLI időpontra; a mai nap még OK.
    if tg_op = 'INSERT'
       and coalesce(auth.role(), '') = 'anon'
       and v_idopont is not null
       and (v_idopont at time zone 'Europe/Budapest')::date
           < (now()      at time zone 'Europe/Budapest')::date then
      raise exception 'Erre az időpontra már nem lehet foglalni (lezárult).';
    end if;

    -- Min. létszám / foglalás — csak a publikus (anon) foglalásra (az admin felülbírálhatja).
    if tg_op = 'INSERT' and coalesce(auth.role(), '') = 'anon'
       and v_min is not null and new.letszam < v_min then
      raise exception 'Erre az időpontra legalább % fős foglalás szükséges.', v_min;
    end if;

    -- Max. foglalások száma — csak a publikus (anon) foglalásra.
    if tg_op = 'INSERT' and coalesce(auth.role(), '') = 'anon' and v_maxfogl is not null then
      select count(*) into v_fogl_szam
      from public.bookings
      where idopont_id = new.idopont_id
        and statusz in ('jovahagyasra_var','jovahagyott')
        and id <> new.id;
      if v_fogl_szam >= v_maxfogl then
        raise exception 'Erre az időpontra már nem fogadható több foglalás.';
      end if;
    end if;

    -- Túlfoglalás elleni védelem (férőhely).
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
select count(*) as korlatozott_idopontok
from public.idopontok
where max_foglalasok is not null or min_letszam is not null;
