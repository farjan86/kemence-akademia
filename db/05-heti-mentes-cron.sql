-- =====================================================================
--  HETI ADATMENTÉS e-mailben (pg_cron + pg_net)
--
--  Hetente meghívja a backup-export Edge Function-t, ami az adatbázis ÖSSZES
--  adattáblájának MINDEN sorát táblánként egy CSV-ben, egy ZIP-ben, egy
--  levélben elküldi a csapat címére (Beállítások → „Csapat e-mail cím").
--  Kép- és csatolmány-fájl nincs a mentésben, csak a rájuk mutató hivatkozás.
--  Részletek: docs/heti-mentes.md
--
--  ELŐFELTÉTELEK:
--   1) Supabase → Database → Extensions: a `pg_cron` és a `pg_net` BE van kapcsolva
--      (a 04-emlekezteto-cron.sql miatt valószínűleg már igen).
--   2) A backup-export függvény deployolva (supabase/functions/backup-export/index.ts).
--   3) Supabase → Edge Functions → Secrets: BACKUP_SECRET beállítva — egy hosszú,
--      véletlen szöveg (32+ karakter). UGYANEZ kerül lent a BEÁLLÍTÁSOK közé.
--   4) Az adminban a Beállítások fülön ki van töltve a Csapat e-mail cím.
--
--  HASZNÁLAT: csak a lenti BEÁLLÍTÁSOK blokkot töltsd ki, a többihez nem kell
--  nyúlni. Újrafuttatható: a régi ütemezést előbb leszedi, és az újat teszi
--  a helyére — időpont-módosításhoz is elég újrafuttatni.
--
--  IDŐZÍTÉS — a cron-kifejezés felépítése
--
--  Öt mező, szóközzel elválasztva:
--
--        ┌─ perc        (0–59)
--        │ ┌─ óra       (0–23)
--        │ │ ┌─ hónap napja   (1–31)
--        │ │ │ ┌─ hónap       (1–12)
--        │ │ │ │ ┌─ hét napja (0 = vasárnap, 1 = hétfő, 2 = kedd … 6 = szombat)
--        │ │ │ │ │
--       '0 4 * * 1'
--
--  A * azt jelenti: „bármelyik". Több érték vesszővel: 1,4 = hétfő ÉS csütörtök.
--  Tartomány kötőjellel: 1-5 = hétfőtől péntekig.
--
--  ⚠️ Az óra UTC-ben értendő. Budapest nyáron UTC+2, télen UTC+1 — tehát
--  a 4 óra = 6:00 nyári / 5:00 téli idő. (A „hétfő reggel" a lényeg, nem a perc.)
--
--  PÉLDÁK:
--     '0 4 * * 1'      hétfő 04:00 UTC (6:00/5:00 Bp.)           ← ÉLES alapértelmezés, heti 1
--     '0 4 * * 1,4'    hétfő ÉS csütörtök 04:00 UTC             heti 2
--     '0 4 * * 1-5'    minden munkanap 04:00 UTC                heti 5
--     '0 4 * * *'      minden nap 04:00 UTC                     napi 1
--     '0 4,16 * * *'   minden nap 04:00 ÉS 16:00 UTC            napi 2
--     '0 12 * * *'     minden nap 12:00 UTC (14:00/13:00 Bp.)   fejlesztői teszthez
--     '0 4 1 * *'      minden hónap 1-jén 04:00 UTC             havi 1
--     '30 20 * * 0'    vasárnap 20:30 UTC (22:30/21:30 Bp.)     hét zárásaként
--
--  Egy konkrét napra (pl. „csak ma 14:00") a cron nem alkalmas — arra az
--  azonnali_teszt kapcsoló való.
-- =====================================================================

create extension if not exists pg_cron;
create extension if not exists pg_net;

do $$
declare
  -- ===================================================================
  --  BEÁLLÍTÁSOK — csak ezt az öt sort kell kitölteni / átírni
  -- ===================================================================
  project_ref    text    := '<PROJECT_REF>';     -- Supabase → Project Settings → API → Project URL (a .supabase.co előtti rész)
  anon_key       text    := '<ANON_KEY>';        -- ugyanott: anon / public kulcs (a függvény kapujának JWT-ellenőrzéséhez)
  backup_secret  text    := '<BACKUP_SECRET>';   -- a 3) pontban beállított secret — a MI kapunk; ez nem publikus
  utemezes       text    := '0 4 * * 1';         -- perc óra hónap-napja hónap hét-napja, UTC-ben — felépítés és példák a fejlécben
  azonnali_teszt boolean := false;               -- true: a beütemezés mellett MOST is elindít egy mentést (teszthez)
  -- ===================================================================

  parancs text;
begin
  if project_ref like '<%' or anon_key like '<%' or backup_secret like '<%' then
    raise exception 'Töltsd ki a BEÁLLÍTÁSOK blokk három helykitöltőjét (project_ref, anon_key, backup_secret).';
  end if;

  -- A cron által futtatandó parancs: a függvény meghívása pg_net-tel.
  -- 10 tábla kiolvasása + levélküldés néhány másodperc — hagyjunk neki időt.
  parancs := format(
    $cmd$select net.http_post(
      url     := %L,
      headers := jsonb_build_object('Content-Type',  'application/json',
                                    'Authorization', %L,
                                    'x-backup-key',  %L),
      body    := '{}'::jsonb,
      timeout_milliseconds := 60000)$cmd$,
    'https://' || project_ref || '.supabase.co/functions/v1/backup-export',
    'Bearer ' || anon_key,
    backup_secret);

  -- Régi ütemezés le, új fel (így az időpont-módosítás is egyszerű újrafuttatás)
  if exists (select 1 from cron.job where jobname = 'kemence-heti-mentes') then
    perform cron.unschedule('kemence-heti-mentes');
  end if;
  perform cron.schedule('kemence-heti-mentes', utemezes, parancs);
  raise notice 'Beütemezve: kemence-heti-mentes, "%" (UTC)', utemezes;

  if azonnali_teszt then
    execute parancs;
    raise notice 'Azonnali teszt elindítva — pár másodperc múlva nézd a net._http_response táblát és a postafiókot.';
  end if;
end $$;

-- ---------------------------------------------------------------------
--  ELLENŐRZÉS
-- ---------------------------------------------------------------------
-- Az ütemezett feladat:
-- select jobname, schedule, active from cron.job where jobname = 'kemence-heti-mentes';

-- A legutóbbi futások (elindult-e a hívás):
-- select start_time, status, return_message
--   from cron.job_run_details
--  where jobid = (select jobid from cron.job where jobname = 'kemence-heti-mentes')
--  order by start_time desc limit 5;

-- A függvény válasza (a pg_net ide teszi): status_code 200 + {"ok":true,...} a jó;
-- 401 = a backup_secret nem egyezik a secrettel; 500 = a függvény Logs füle mondja meg.
-- select created, status_code, content::text
--   from net._http_response
--  order by created desc limit 5;

-- KIKAPCSOLÁS: select cron.unschedule('kemence-heti-mentes');
