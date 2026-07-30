-- =====================================================================
--  Migráció: az "elmaradt" a PROGRAM állapota legyen, ne a foglalásé.
--    - workshops.statusz: új 'elmaradt' érték (aktiv / hamarosan / elmaradt)
--    - bookings.statusz: az 'elmaradt' ELTÁVOLÍTVA (a meglévők → 'lemondott')
--    - trigger: az "aktív program" + túlfoglalás ellenőrzés csak akkor fusson,
--      ha a foglalás AKTÍV státuszba kerül (így lezárt foglalás bármikor
--      módosítható elmaradt/archivált programon is).
-- =====================================================================

-- 1) A korábban 'elmaradt'-ra állított FOGLALÁSOK → 'lemondott'
update public.bookings set statusz = 'lemondott' where statusz = 'elmaradt';

-- 2) bookings.statusz: vissza a 4 értékre (nincs 'elmaradt')
alter table public.bookings drop constraint if exists bookings_statusz_chk;
alter table public.bookings drop constraint if exists bookings_statusz_check;
alter table public.bookings add constraint bookings_statusz_chk
  check (statusz in ('jovahagyasra_var','jovahagyott','elutasitott','lemondott'));

-- 3) workshops.statusz: 'elmaradt' hozzáadása
alter table public.workshops drop constraint if exists workshops_statusz_check;
alter table public.workshops drop constraint if exists workshops_statusz_chk;
alter table public.workshops add constraint workshops_statusz_chk
  check (statusz in ('aktiv','hamarosan','elmaradt'));

-- 4) Trigger: csak aktív (helyet foglaló) státusznál ellenőrizzük a programot + szabad helyet
create or replace function public.ellenoriz_szabad_hely()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_max     integer;
  v_statusz text;
  v_foglalt integer;
begin
  if new.statusz in ('jovahagyasra_var','jovahagyott') then
    select max_letszam, statusz into v_max, v_statusz
    from public.workshops where id = new.workshop_id;

    if v_statusz is distinct from 'aktiv' then
      raise exception 'Erre a programra nem lehet foglalni (nem aktív).';
    end if;

    select coalesce(sum(letszam),0) into v_foglalt
    from public.bookings
    where workshop_id = new.workshop_id
      and statusz in ('jovahagyasra_var','jovahagyott')
      and id <> new.id;

    if v_foglalt + new.letszam > coalesce(v_max,0) then
      raise exception 'Nincs elég szabad hely (% szabad).', greatest(coalesce(v_max,0) - v_foglalt, 0);
    end if;
  end if;
  return new;
end;
$$;
