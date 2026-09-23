-- =====================================================================
--  DEV-MIGRÁCIÓ: számlázási címadatok + ajánlatkérési info-sáv
--
--  Három ÚJ mező mindkét táblán (bookings, ajanlatok):
--    • iranyitoszam  (max  20 karakter) — szabad szöveg, külföldi címek miatt
--    • helyseg       (max 100 karakter) — szabad szöveg
--    • cim_tovabbi   (max 200 karakter) — kerület, utca, házszám, stb.
--
--  A NYILVÁNOS (anon) beküldésnél mindhárom KÖTELEZŐ — ezt egy trigger
--  őrzi. Az adminból mentett/importált sor maradhat cím nélkül (a régi
--  foglalásoknál nem is volt bekérve).
--
--  Emellett egy ÚJ beállítás: settings.ajanlat_infosav — az ajánlatkérő űrlap
--  tetején megjelenő szöveg (a foglalási info-sáv párja). Ide kerül például a
--  számlázásról szóló tájékoztatás, hogy az admin bármikor átírhassa.
--
--  HOL FUTTASD: a MEGLÉVŐ adatbázisokban — a fejlesztői ÉS a demó Supabase
--  projektben (SQL Editor). Új (éles) projekthez nem kell: a végleges séma
--  a db/01-schema.sql-ben van, az már tartalmazza ezeket.
--
--  Újrafuttatható: minden lépés „if not exists” / „drop … if exists” mintájú.
-- =====================================================================

-- ---------------------------------------------------------------------
--  1) Oszlopok
--     Szándékosan NEM „not null”: a korábbi sorokban nincs adat, és az
--     adminnak is engedjük a cím nélküli mentést (pl. Minup-import).
-- ---------------------------------------------------------------------
alter table public.bookings
  add column if not exists iranyitoszam text,
  add column if not exists helyseg      text,
  add column if not exists cim_tovabbi  text;

alter table public.ajanlatok
  add column if not exists iranyitoszam text,
  add column if not exists helyseg      text,
  add column if not exists cim_tovabbi  text;

-- ---------------------------------------------------------------------
--  2) Hosszkorlátok (szabad szöveg, de ne lehessen parttalan)
-- ---------------------------------------------------------------------
alter table public.bookings drop constraint if exists bookings_cim_hossz;
alter table public.bookings add  constraint bookings_cim_hossz check (
      (iranyitoszam is null or char_length(iranyitoszam) <= 20)
  and (helyseg      is null or char_length(helyseg)      <= 100)
  and (cim_tovabbi  is null or char_length(cim_tovabbi)  <= 200));

alter table public.ajanlatok drop constraint if exists ajanlatok_cim_hossz;
alter table public.ajanlatok add  constraint ajanlatok_cim_hossz check (
      (iranyitoszam is null or char_length(iranyitoszam) <= 20)
  and (helyseg      is null or char_length(helyseg)      <= 100)
  and (cim_tovabbi  is null or char_length(cim_tovabbi)  <= 200));

-- ---------------------------------------------------------------------
--  3) A nyilvános beküldésnél mindhárom mező kötelező
--     Ugyanaz a függvény őrzi a foglalást és az ajánlatkérést is.
--     Csak az anon (böngészőből jövő) INSERT-re vonatkozik — az adminból
--     (authenticated) és az SQL Editorból mentett sor átmegy.
-- ---------------------------------------------------------------------
create or replace function public.ellenoriz_cimadatok()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(auth.role(), '') = 'anon' then
    if coalesce(btrim(new.iranyitoszam), '') = '' then
      raise exception 'Az irányítószám megadása kötelező.';
    end if;
    if coalesce(btrim(new.helyseg), '') = '' then
      raise exception 'A helység megadása kötelező.';
    end if;
    if coalesce(btrim(new.cim_tovabbi), '') = '' then
      raise exception 'A további címadat megadása kötelező.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_cimadatok_booking on public.bookings;
create trigger trg_cimadatok_booking
  before insert on public.bookings
  for each row execute function public.ellenoriz_cimadatok();

drop trigger if exists trg_cimadatok_ajanlat on public.ajanlatok;
create trigger trg_cimadatok_ajanlat
  before insert on public.ajanlatok
  for each row execute function public.ellenoriz_cimadatok();

-- ---------------------------------------------------------------------
--  4) Ajánlatkérési info-sáv (a foglalási info-sáv párja)
-- ---------------------------------------------------------------------
alter table public.settings
  add column if not exists ajanlat_infosav text;

-- ---------------------------------------------------------------------
--  5) Szóhasználat: az „ötlet" szó helyett mindenhol „egyedi program"
--     Csak az érintett sablon-szövegrészt cseréli, a saját szerkesztéseket nem bántja.
-- ---------------------------------------------------------------------
update public.ajanlat_sablonok
   set torzs = replace(torzs, 'Program/ötlet:', 'Egyedi program:'),
       updated_at = now()
 where torzs like '%Program/ötlet:%';

-- ---------------------------------------------------------------------
--  6) Ellenőrzés — mindkét sornak 3-at kell adnia
-- ---------------------------------------------------------------------
select 'bookings'  as tabla,
       count(*) filter (where column_name in ('iranyitoszam','helyseg','cim_tovabbi')) as uj_oszlopok
from information_schema.columns
where table_schema = 'public' and table_name = 'bookings'
union all
select 'ajanlatok',
       count(*) filter (where column_name in ('iranyitoszam','helyseg','cim_tovabbi'))
from information_schema.columns
where table_schema = 'public' and table_name = 'ajanlatok';
