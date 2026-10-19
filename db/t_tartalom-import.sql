-- =====================================================================
--  TARTALOM-IMPORT — a CÉL projektben futtasd (az új, éles adatbázisban)
--
--  Előfeltétel: a cél adatbázisban már lefutott a `db/01-schema.sql`
--  (és a 02–04 fájlok), tehát a táblák léteznek.
--
--  MIT HOZ ÁT:  programok, időpontok, egyedi programok, előadók,
--               program–előadó kapcsolatok, beállítások, levélsablonok
--  MIT NEM:     foglalások, ajánlatkérések, levélnaplók, látogatásszám.
--               Ezeket a célban nem is bántja — egyszerűen nem nyúl hozzájuk.
--
--  HASZNÁLAT — négy lépés
--
--   1) KÉPEK.  A forrás projekt Storage → `program-fotok` mappájából töltsd
--      le a fájlokat, és a cél projekt UGYANILYEN NEVŰ, publikus tárolójába
--      töltsd fel őket — fontos, hogy a FÁJLNEVEK ne változzanak.
--
--   2) ADAT.  A `t_tartalom-export.sql` által adott JSON-t illeszd be lent,
--      a `null` helyére. Átalakítani nem kell, ahogy kimásoltad, úgy jó.
--
--   3) CÉL WEBCÍM.  Írd át az `uj_bazis` értékét a CÉL projekt webcímére
--      (Supabase → Settings → API → Project URL), pl.:
--          https://abcdefghijklmnop.supabase.co
--
--   4) KAPCSOLÓK.  Alapértelmezésben CSAK ÜRES cél adatbázisba enged
--      importálni, és a meglévő sorokat nem írja felül. Lásd a két
--      kapcsolót a `declare` részben.
-- =====================================================================

do $$
declare
  -- ===================================================================
  --  BEÁLLÍTÁSOK
  -- ===================================================================

  -- 3) A CÉL projekt webcíme (a képek címének átírásához)
  uj_bazis text := 'https://IDE-A-CEL-PROJEKT-REFERENCIAJA.supabase.co';

  -- 4a) true  = csak akkor fut le, ha a célban MÉG NINCS tartalom.
  --            Ez véd attól, hogy egy használatban lévő adatbázisba
  --            véletlenül bemásoljuk a forrás programjait is — mert azok
  --            a meglévők MELLÉ kerülnének, nem helyettük.
  --     false = a vegyítést is megengedi (tudatos döntés).
  csak_ures_celba boolean := true;

  -- 4b) false = a célban MÁR MEGLÉVŐ sorokat (azonos azonosítóval) békén hagyja.
  --     true  = felülírja őket a forrásbeli tartalommal. Akkor hasznos, ha a
  --             forrásban utólag javítottál egy szöveget vagy képet, és azt
  --             újra ki akarod tolni. A foglalásokat ez sem érinti.
  meglevoket_frissitse boolean := false;

  -- 2) ⬇⬇⬇ IDE ILLESZD BE az exportált JSON-t — a lenti `null` HELYÉRE ⬇⬇⬇
  adat jsonb := $json$
null
  $json$::jsonb;
  -- ⬆⬆⬆ eddig tart a beillesztett JSON ⬆⬆⬆

  db       integer;
  meglevo  integer;
  foglalas integer;
begin
  -- -------------------------------------------------------------------
  --  Biztonsági ellenőrzések
  -- -------------------------------------------------------------------
  if adat is null then
    raise exception 'Nincs beillesztve adat. Lásd a fájl tetején a 2) lépést.';
  end if;
  if uj_bazis like '%IDE-A-CEL-PROJEKT%' then
    raise exception 'Töltsd ki az `uj_bazis` értékét a cél projekt webcímével (3) lépés).';
  end if;

  select (select count(*) from public.workshops)
       + (select count(*) from public.egyedi_programok)
       + (select count(*) from public.eloadok)   into meglevo;
  select (select count(*) from public.bookings)
       + (select count(*) from public.ajanlatok) into foglalas;

  if meglevo > 0 and csak_ures_celba then
    raise exception
      E'A cél adatbázis NEM üres: % tartalmi sor (program / egyedi program / előadó),\n'
       'és % foglalás vagy ajánlatkérés van benne.\n\n'
       'A szkript ilyenkor alapértelmezésben megáll, mert a forrás tartalma a meglévők\n'
       'MELLÉ kerülne: azonos című, de külön programok jönnének létre.\n\n'
       'Ha tudatosan vállalod a vegyítést, állítsd a `csak_ures_celba` kapcsolót false-ra.\n'
       'Ha a meglévő sorokat FRISSÍTENI szeretnéd a forrásbeliekkel, ezen felül a\n'
       '`meglevoket_frissitse` kapcsolót is állítsd true-ra.',
      meglevo, foglalas;
  end if;

  if foglalas > 0 then
    raise notice 'FIGYELEM: a célban már van % foglalás/ajánlatkérés. Ezekhez a szkript nem nyúl.', foglalas;
  end if;

  -- -------------------------------------------------------------------
  --  1) Programok  (a hivatkozások miatt ez megy elsőként)
  -- -------------------------------------------------------------------
  --  A `slug` (megosztható link) EGYEDI. Ha egy bejövő program slugja a
  --  célban már egy MÁSIK programé, a kulcsot elhagyjuk a bejövő sorból:
  --  a beszúrási trigger képez újat (-2, -3, …). A célban meglévő sorok
  --  slugját nem írjuk felül, így a már megosztott linkjeik tovább élnek.
  insert into public.workshops
  select * from jsonb_populate_recordset(null::public.workshops,
    coalesce((select jsonb_agg(case when exists (select 1 from public.workshops w
                                                  where w.slug = e->>'slug'
                                                    and w.id::text <> e->>'id')
                                    then e - 'slug' else e end)
                from jsonb_array_elements(adat->'workshops') e), '[]'::jsonb))
  on conflict (id) do update set
    cim                    = excluded.cim,
    rovid_leiras           = excluded.rovid_leiras,
    leiras                 = excluded.leiras,
    varhato_idotartam      = excluded.varhato_idotartam,
    foto_url               = excluded.foto_url,
    statusz                = excluded.statusz,
    archivalt              = excluded.archivalt,
    foglalas_felfuggesztve = excluded.foglalas_felfuggesztve,
    sorrend                = excluded.sorrend
  where meglevoket_frissitse;
  get diagnostics db = row_count;  raise notice 'programok: % sor', db;

  -- -------------------------------------------------------------------
  --  2) Időpontok  (a programokra hivatkoznak)
  -- -------------------------------------------------------------------
  insert into public.idopontok
  select * from jsonb_populate_recordset(null::public.idopontok, adat->'idopontok')
  on conflict (id) do update set
    workshop_id     = excluded.workshop_id,
    idopont         = excluded.idopont,
    ar              = excluded.ar,
    kedvezmenyes_ar = excluded.kedvezmenyes_ar,
    max_letszam     = excluded.max_letszam,
    max_foglalasok  = excluded.max_foglalasok,
    min_letszam     = excluded.min_letszam,
    statusz         = excluded.statusz
  where meglevoket_frissitse;
  get diagnostics db = row_count;  raise notice 'időpontok: % sor', db;

  -- -------------------------------------------------------------------
  --  3) Egyedi programok
  -- -------------------------------------------------------------------
  insert into public.egyedi_programok
  select * from jsonb_populate_recordset(null::public.egyedi_programok, adat->'egyedi_programok')
  on conflict (id) do update set
    cim          = excluded.cim,
    rovid_leiras = excluded.rovid_leiras,
    leiras       = excluded.leiras,
    foto_url     = excluded.foto_url,
    sorrend      = excluded.sorrend,
    archivalt    = excluded.archivalt
  where meglevoket_frissitse;
  get diagnostics db = row_count;  raise notice 'egyedi programok: % sor', db;

  -- -------------------------------------------------------------------
  --  4) Előadók, majd a program–előadó kapcsolatok
  -- -------------------------------------------------------------------
  insert into public.eloadok
  select * from jsonb_populate_recordset(null::public.eloadok, adat->'eloadok')
  on conflict (id) do update set
    nev          = excluded.nev,
    bemutatkozas = excluded.bemutatkozas,
    foto_url     = excluded.foto_url,
    sorrend      = excluded.sorrend,
    rejtett      = excluded.rejtett
  where meglevoket_frissitse;
  get diagnostics db = row_count;  raise notice 'előadók: % sor', db;

  -- A kapcsolótáblán a két azonosító EGYÜTT a kulcs — nincs rajta mit frissíteni.
  insert into public.program_eloadok
  select * from jsonb_populate_recordset(null::public.program_eloadok, adat->'program_eloadok')
  on conflict (workshop_id, eloado_id) do nothing;
  get diagnostics db = row_count;  raise notice 'program–előadó kapcsolat: % új sor', db;

  -- -------------------------------------------------------------------
  --  5) Beállítások (egysoros tábla)
  --     Üres célnál mindig átjön. Nem üres célnál csak kérésre — különben
  --     felülírná pl. az ott beállított csapat e-mail címet.
  -- -------------------------------------------------------------------
  insert into public.settings
  select * from jsonb_populate_recordset(null::public.settings, adat->'settings')
  on conflict (id) do update set
    levelezesi_email         = excluded.levelezesi_email,
    foglalas_infosav         = excluded.foglalas_infosav,
    ajanlat_infosav          = excluded.ajanlat_infosav,
    azonosito_elotag         = excluded.azonosito_elotag,
    azonosito_kezdo          = excluded.azonosito_kezdo,
    ajanlat_azonosito_elotag = excluded.ajanlat_azonosito_elotag,
    ajanlat_azonosito_kezdo  = excluded.ajanlat_azonosito_kezdo,
    naptar_nezet             = excluded.naptar_nezet,
    foglalas_szunet          = excluded.foglalas_szunet,
    updated_at               = now()
  where meglevoket_frissitse or meglevo = 0;
  get diagnostics db = row_count;  raise notice 'beállítások: % sor', db;

  -- -------------------------------------------------------------------
  --  6) Levélsablonok (a szerkesztett szövegek) — ugyanaz a logika
  -- -------------------------------------------------------------------
  insert into public.email_sablonok
  select * from jsonb_populate_recordset(null::public.email_sablonok, adat->'email_sablonok')
  on conflict (tipus) do update set
    targy = excluded.targy, torzs = excluded.torzs, updated_at = now()
  where meglevoket_frissitse or meglevo = 0;
  get diagnostics db = row_count;  raise notice 'foglalási sablonok: % sor', db;

  insert into public.ajanlat_sablonok
  select * from jsonb_populate_recordset(null::public.ajanlat_sablonok, adat->'ajanlat_sablonok')
  on conflict (tipus) do update set
    targy = excluded.targy, torzs = excluded.torzs, updated_at = now()
  where meglevoket_frissitse or meglevo = 0;
  get diagnostics db = row_count;  raise notice 'ajánlati sablonok: % sor', db;

  -- -------------------------------------------------------------------
  --  7) Képcímek átírása a CÉL projektre
  --     A fájlnév és az elérési út változatlan, csak a kiszolgáló cserélődik.
  --     Ami már a cél projektre mutat, azt békén hagyja.
  -- -------------------------------------------------------------------
  update public.workshops
     set foto_url = regexp_replace(foto_url, '^https?://[^/]+', uj_bazis)
   where foto_url is not null and position(uj_bazis in foto_url) <> 1;
  get diagnostics db = row_count;  raise notice 'program-képek átírva: %', db;

  update public.egyedi_programok
     set foto_url = regexp_replace(foto_url, '^https?://[^/]+', uj_bazis)
   where foto_url is not null and position(uj_bazis in foto_url) <> 1;
  get diagnostics db = row_count;  raise notice 'egyedi program képek átírva: %', db;

  update public.eloadok
     set foto_url = regexp_replace(foto_url, '^https?://[^/]+', uj_bazis)
   where foto_url is not null and position(uj_bazis in foto_url) <> 1;
  get diagnostics db = row_count;  raise notice 'előadó-képek átírva: %', db;
end $$;

-- =====================================================================
--  ELLENŐRZÉS — futtasd le az import után
-- =====================================================================
select 'programok'        as tabla, count(*) from public.workshops
union all select 'időpontok',               count(*) from public.idopontok
union all select 'egyedi programok',        count(*) from public.egyedi_programok
union all select 'előadók',                 count(*) from public.eloadok
union all select 'program–előadó kapcs.',   count(*) from public.program_eloadok
union all select 'foglalás',                count(*) from public.bookings
union all select 'ajánlatkérés',            count(*) from public.ajanlatok;

-- Minden képcím a cél projektre mutat-e már?
select 'program' as mihez, cim as nev, foto_url from public.workshops        where foto_url is not null
union all
select 'egyedi',            cim,       foto_url from public.egyedi_programok where foto_url is not null
union all
select 'előadó',            nev,       foto_url from public.eloadok          where foto_url is not null
order by mihez, nev;

-- =====================================================================
--  AMI EZEN FELÜL KÉZI BEÁLLÍTÁS (nem másolható adat) — lásd install.html
--    • admin fiók létrehozása (Supabase Auth)
--    • Storage tárolók: program-fotok (publikus), ajanlat-csatolmanyok (privát)
--    • Edge Function titkok: RESEND_API_KEY, MAIL_FROM
--    • a visszaigazoló trigger és a napi emlékeztető <PROJECT_REF>/<ANON_KEY> értékei
--    • a web/js/config.js átírása a cél projekt URL-jére és anon kulcsára
--    • a settings „Csapat e-mail cím” és az azonosító-kezdőérték átnézése
-- =====================================================================
