-- =====================================================================
--  JAVÍTÓ SZKRIPT (j_): biztonsági javítások (2026-10-22-i penteszt nyomán)
--
--  A "j_" előtag MEGLÉVŐ, MÁR FUTÓ projekten futtatandó javítást jelent —
--  külön kategória az "m_" (dev-migráció, új funkcióhoz) és a "t_"
--  (technikai, újrahasználható eszköz) mellett. Lásd docs/technikai-
--  dokumentacio.md a teljes elnevezési konvencióért.
--
--  Négy, egymástól független, NEM DESTRUKTÍV javítás egy fájlban:
--    1) Az ajánlatkérés admin-privát mezői (belso_jegyzet, vegleges_ar, …)
--       nyilvános beküldésnél mindig üresek lesznek — eddig egy anon POST
--       ezeket is beállíthatta, pedig az admin kizárólagos mezői.
--    2) A settings.levelezesi_email (csapat e-mail cím) nem olvasható többé
--       anonim módon — eddig a teljes settings-sor, benne ezzel is,
--       bárki számára lekérhető volt.
--    3) A bookings/ajanlatok azonosito oszlopa a kliens által többé nem
--       felülírható (GENERATED ALWAYS) — eddig egy anon beküldés
--       „elfoglalhatta” előre a következő sorszámokat.
--    4) A Storage buckettek szerveroldali fájlméret- és típus-korlátot
--       kapnak — eddig csak a böngészős JS ellenőrzött, API-n megkerülhetően.
--
--  SEMMI MEGLÉVŐ ADATOT NEM ÍR FELÜL, NEM TÖRÖL, és a program eddigi
--  működésén (publikus űrlapok, admin felület) semmit nem változtat —
--  csak az eddig nyitva hagyott kiskapukat zárja.
--
--  HOL FUTTASD: a MEGLÉVŐ adatbázisokban — fejlesztői, demó ÉS éles.
--  (A fejlesztőin 2026-10-22-én lefutott és élőben leellenőrzött — lásd
--  eles-javitasok-telepitese.html.) Új projekthez nem kell: a
--  db/01-schema.sql és a db/02-storage.sql már tartalmazza. Újrafuttatható.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
--  1) Ajánlat admin-privát mezőinek zárolása nyilvános beküldésnél
-- ---------------------------------------------------------------------
create or replace function public.ajanlat_privat_mezok_torlese()
returns trigger
language plpgsql
as $$
begin
  if coalesce(auth.role(), '') = 'anon' then
    new.belso_jegyzet   := null;
    new.vegleges_ar      := null;
    new.vegleges_idopont := null;
    new.vegleges_letszam := null;
    new.ajanlat_szoveg   := null;
    new.csatolmany_url   := null;
    new.valasz_elkuldve  := null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_ajanlat_privat_mezok on public.ajanlatok;
create trigger trg_ajanlat_privat_mezok
  before insert on public.ajanlatok
  for each row execute function public.ajanlat_privat_mezok_torlese();

-- ---------------------------------------------------------------------
--  2) settings.levelezesi_email elzárása anontól
--     FONTOS: a Postgres a TÁBLA-szintű és OSZLOP-szintű jogot külön
--     tartja nyilván — ha anonnak már megvan a tábla-szintű SELECT-je
--     (a projekt induló "Data API jogok" blokkja miatt mindenhol megvan),
--     egy önálló oszlop-szintű REVOKE nem bírja felül. Ezért előbb a
--     TELJES tábla-szintű jogot vesszük el, majd oszloponként visszaadjuk,
--     a levelezesi_email KIHAGYÁSÁVAL. Az admint (authenticated) nem érinti.
-- ---------------------------------------------------------------------
revoke select on public.settings from anon;
grant select (id, foglalas_infosav, ajanlat_infosav, azonosito_elotag, azonosito_kezdo,
              naptar_nezet, foglalas_szunet, ajanlat_azonosito_elotag, ajanlat_azonosito_kezdo,
              updated_at)
  on public.settings to anon;

-- ---------------------------------------------------------------------
--  3) azonosito oszlopok: a kliens többé nem adhat meg saját értéket.
--     Ez csak a JÖVŐBELI beszúrásokat szigorítja, a meglévő azonosito
--     értékeket nem változtatja, nem is nullázza, a sorozat állását sem
--     állítja vissza — pontosan ott folytatódik, ahol most áll.
-- ---------------------------------------------------------------------
alter table public.bookings  alter column azonosito set generated always;
alter table public.ajanlatok alter column azonosito set generated always;

-- ---------------------------------------------------------------------
--  4) Storage buckettek: szerveroldali fájlméret- és típus-korlát.
--     Ez a már feltöltött fájlokat NEM érinti — csak az ezutáni
--     feltöltéseket korlátozza. Ha a bucket esetleg még nem létezne
--     (friss projekt, a 02-storage.sql még nem futott), az UPDATE
--     egyszerűen 0 sort érint — nem hiba.
-- ---------------------------------------------------------------------
update storage.buckets set
  file_size_limit = 10485760,   -- 10 MB
  allowed_mime_types = array['image/jpeg','image/png','image/webp','image/gif']
where id = 'program-fotok';

update storage.buckets set
  file_size_limit = 20971520,   -- 20 MB
  allowed_mime_types = array['application/pdf','image/jpeg','image/png',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'text/plain']
where id = 'ajanlat-csatolmanyok';

commit;

-- ---------------------------------------------------------------------
--  ELLENŐRZÉS (már a lezárt tranzakció után)
-- ---------------------------------------------------------------------
-- 1) A trigger létezik:
-- select tgname from pg_trigger where tgrelid = 'public.ajanlatok'::regclass and tgname = 'trg_ajanlat_privat_mezok';

-- 2) Az anon NEM lát levelezesi_email-t (0 sort kell adnia):
-- select grantee, privilege_type, column_name
--   from information_schema.column_privileges
--  where table_name = 'settings' and column_name = 'levelezesi_email' and grantee = 'anon';

-- 3) Az azonosito oszlopok "always" módban vannak (mindkét sor "ALWAYS"-t kell adjon):
-- select table_name, column_name, is_identity, identity_generation
--   from information_schema.columns
--  where table_name in ('bookings','ajanlatok') and column_name = 'azonosito';

-- 4) A buckettek korlátai:
-- select id, file_size_limit, allowed_mime_types from storage.buckets
--  where id in ('program-fotok','ajanlat-csatolmanyok');
