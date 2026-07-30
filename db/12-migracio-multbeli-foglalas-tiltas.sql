-- =====================================================================
--  Migráció: MÚLTBÉLI eseményre ne lehessen PUBLIKUSAN foglalni
--
--  Ok: egy még nem archivált, de már lezajlott (múltbéli) program
--  „aktív” maradhat egy ideig — ilyenkor a publikus oldalon nem szabad
--  rá foglalni. Szabály: a program NAPJA alapján döntünk — a MAI nap
--  még foglalható, a korábbi napok nem. (Európa/Budapest időzóna.)
--
--  A tiltás CSAK a publikus (anon) beszúrásra vonatkozik. Az admin és a
--  seed (SQL Editor = nem anon) továbbra is rögzíthet historikus adatot
--  (pl. lezajlott programhoz jóváhagyott/lemondott foglalást).
--
--  A 01-schema.sql már ezt a (frissített) triggert tartalmazza — ez a
--  fájl a MÁR FUTÓ fejlesztői DB-t hozza szinkronba. Csak a trigger-
--  függvényt cseréli, a trigger maga változatlan.
-- =====================================================================

create or replace function public.ellenoriz_szabad_hely()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_max     integer;
  v_statusz text;
  v_idopont timestamptz;
  v_foglalt integer;
begin
  -- Csak a helyet foglaló (aktív) státuszoknál ellenőrzünk: így lezárt foglalás
  -- (lemondott/elutasított) bármikor módosítható elmaradt/archivált programon is.
  if new.statusz in ('jovahagyasra_var','jovahagyott') then
    select max_letszam, statusz, idopont into v_max, v_statusz, v_idopont
    from public.workshops where id = new.workshop_id;

    if v_statusz is distinct from 'aktiv' then
      raise exception 'Erre a programra nem lehet foglalni (nem aktív).';
    end if;

    -- Publikus (anon) foglalás NEM mehet MÚLTBÉLI eseményre; a mai nap még OK.
    -- Az admin / seed (nem anon) rögzíthet historikus adatot (pl. lezajlott program).
    if tg_op = 'INSERT'
       and coalesce(auth.role(), '') = 'anon'
       and v_idopont is not null
       and (v_idopont at time zone 'Europe/Budapest')::date
           < (now()      at time zone 'Europe/Budapest')::date then
      raise exception 'Erre a programra már nem lehet foglalni (lezárult).';
    end if;

    select coalesce(sum(letszam),0) into v_foglalt
    from public.bookings
    where workshop_id = new.workshop_id
      and statusz in ('jovahagyasra_var','jovahagyott')
      and id <> new.id;                        -- saját magát ne számolja (update)

    if v_foglalt + new.letszam > coalesce(v_max,0) then
      raise exception 'Nincs elég szabad hely (% szabad).',
        greatest(coalesce(v_max,0) - v_foglalt, 0);
    end if;
  end if;

  return new;
end;
$$;
