-- =====================================================================
--  Migráció: NAPI EMLÉKEZTETŐ (pg_cron + pg_net)
--
--  Minden nap lefut, és a MÁSNAPI, JÓVÁHAGYOTT foglalásoknak kiküldi az
--  „emlekezteto" levelet a send-email Edge Function-ön keresztül.
--
--  ELŐFELTÉTELEK:
--   1) Supabase → Database → Extensions: kapcsold BE a `pg_cron` és a `pg_net` bővítményt.
--   2) Fusson le a 13-as migráció (az „emlekezteto" sablon), és legyen deployolva a send-email függvény.
--
--  ⚠️ A lenti <PROJECT_REF> és <ANON_KEY> HELYÉRE írd a saját projekted adatait
--     (Supabase → Project Settings → API). Az ANON kulcs kell a függvény JWT-ellenőrzéséhez.
--     Az időzóna Europe/Budapest; a cron időpontja szerver-időben (UTC) értendő.
-- =====================================================================

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Régi ütemezés eltávolítása, ha újrafuttatod ezt a fájlt
do $$
begin
  if exists (select 1 from cron.job where jobname = 'kemence-napi-emlekezteto') then
    perform cron.unschedule('kemence-napi-emlekezteto');
  end if;
end $$;

-- Napi 8:00 (UTC) — a MÁSNAP esedékes, JÓVÁHAGYOTT foglalásoknak megy az emlékeztető.
select cron.schedule(
  'kemence-napi-emlekezteto',
  '0 8 * * *',
  $$
    select net.http_post(
      url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/send-email',
      headers := jsonb_build_object(
                   'Content-Type', 'application/json',
                   'Authorization', 'Bearer <ANON_KEY>'
                 ),
      body    := jsonb_build_object('booking_id', b.id, 'tipus', 'emlekezteto')
    )
    from public.bookings b
    join public.idopontok i on i.id = b.idopont_id
    where b.statusz = 'jovahagyott'
      and (i.idopont at time zone 'Europe/Budapest')::date
          = ((now() at time zone 'Europe/Budapest')::date + 1)
  $$
);

-- Ellenőrzés: az ütemezett feladat
-- select jobname, schedule, active from cron.job where jobname = 'kemence-napi-emlekezteto';

-- AZONNALI TESZT (nem kell a napi 8:00-ra várni): pár jóváhagyott foglalónak rögtön küld
-- emlékeztetőt, dátumszűrő nélkül. A <PROJECT_REF>/<ANON_KEY> ide is kitöltendő.
-- select net.http_post(
--   url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/send-email',
--   headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer <ANON_KEY>'),
--   body    := jsonb_build_object('booking_id', b.id, 'tipus', 'emlekezteto')
-- )
-- from public.bookings b where b.statusz = 'jovahagyott' limit 3;
