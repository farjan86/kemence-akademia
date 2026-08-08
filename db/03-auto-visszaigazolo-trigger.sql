-- =====================================================================
--  Migráció: AUTOMATIKUS VISSZAIGAZOLÓ + CSAPAT-ÉRTESÍTŐ (trigger + pg_net)
--
--  Ugyanaz, mint a Supabase „Database Webhook", csak SQL-ből — így nem kell
--  a felületen keresgélni. Amikor ÚJ, „jóváhagyásra vár" foglalás kerül a
--  bookings táblába, meghívja a send-email függvényt, ami kiküldi a
--  visszaigazolót (vendég) + a csapat-értesítőt (csapat cím).
--
--  ELŐFELTÉTELEK:
--   1) Supabase → Database → Extensions: kapcsold BE a `pg_net` bővítményt.
--   2) A send-email függvény legyen deployolva (a webhook-módos, legfrissebb kóddal).
--
--  ⚠️ A <PROJECT_REF> és <ANON_KEY> HELYÉRE írd a saját projekted adatait
--     (Supabase → Project Settings → API).
-- =====================================================================

create extension if not exists pg_net;

create or replace function public.trg_uj_foglalas_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Csak új, PUBLIKUS foglalásnál (jóváhagyásra vár). A send-email függvény
  -- ugyanezt a "type/record" payloadot várja, mint a Supabase Database Webhook.
  if new.statusz = 'jovahagyasra_var' then
    perform net.http_post(
      url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/send-email',
      headers := jsonb_build_object(
                   'Content-Type', 'application/json',
                   'Authorization', 'Bearer <ANON_KEY>'
                 ),
      body    := jsonb_build_object('type', 'INSERT', 'record', to_jsonb(new))
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_uj_foglalas_email on public.bookings;
create trigger trg_uj_foglalas_email
after insert on public.bookings
for each row execute function public.trg_uj_foglalas_email();

-- Kikapcsolás (ha kell): drop trigger trg_uj_foglalas_email on public.bookings;

-- =====================================================================
--  AJÁNLAT auto-visszaigazoló + csapat-értesítő (a send-AJANLAT-email függvényt hívja)
--
--  Ugyanaz a minta, mint fent, de az `ajanlatok` INSERT-re, és a payloadban
--  szerepel a `table: 'ajanlatok'`, hogy a függvény meg tudja különböztetni.
--
--  ELŐFELTÉTEL: a send-ajanlat-email függvény deployolva (lásd install.html 2.6).
--  ⚠️ A <PROJECT_REF> és <ANON_KEY> HELYÉRE ugyanaz, mint a foglalás-triggernél.
-- =====================================================================
create or replace function public.trg_uj_ajanlat_email()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.statusz = 'ajanlatra_var' then
    perform net.http_post(
      url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/send-ajanlat-email',
      headers := jsonb_build_object(
                   'Content-Type', 'application/json',
                   'Authorization', 'Bearer <ANON_KEY>'
                 ),
      body    := jsonb_build_object('type', 'INSERT', 'table', 'ajanlatok', 'record', to_jsonb(new))
    );
  end if;
  return new;
end; $$;

drop trigger if exists trg_uj_ajanlat_email on public.ajanlatok;
create trigger trg_uj_ajanlat_email
after insert on public.ajanlatok
for each row execute function public.trg_uj_ajanlat_email();

-- Kikapcsolás (ha kell): drop trigger trg_uj_ajanlat_email on public.ajanlatok;
