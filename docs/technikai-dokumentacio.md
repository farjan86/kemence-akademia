# Kemence Akadémia — Technikai dokumentáció

> Ez a fájl **mindig a jelenlegi, tényleges állapotot** írja le (nem a tervet — az a `fejlesztesi-terv.md`).
> Utolsó frissítés: 2026-08-04 (a „több időpont" átalakítás után).

## 1. Architektúra

- **Frontend:** statikus HTML/CSS/JS (nincs build lépés, nincs framework). A böngésző a `@supabase/supabase-js` CDN-klienssel beszél a Supabase-szel.
- **Backend:** **Supabase** (PostgreSQL + Auth + RLS + Storage + **Edge Functions**).
- **Levélküldés:** **Resend** (a `send-email` Edge Function-ön át). Automatika: **Database Webhook / trigger** (foglaláskori auto-levél) és **pg_cron** (napi emlékeztető). Részletek: `docs/email.md`, `install.html`.
- **Hoszting:** fejlesztéskor helyi Python szerver (localhost:5500); élesben **Hostinger** (statikus fájlok). Az adat mindig a Supabase-ből jön.
- **Tulajdon:** a Supabase-projekt az ügyfélé, a fejlesztő meghívott közreműködő. Demó a fejlesztő saját fiókján.

## 2. Projektstruktúra

```
db/                         SQL — adatbázis. Elnevezés: base (01–04) · m_ = dev-migráció (ideiglenes) · t_ = technikai eszköz
  01-schema.sql             A TELJES, mindig naprakész séma (üres/éles telepítéshez elég ez): workshops (program) + idopontok (alkalom) + bookings (idopont_id) + settings, RLS, „programok" nézet, túlfoglalás-trigger, 7 e-mail sablon, alap-beállítások, látogatás-számláló
  02-storage.sql            Storage bucket a program-fotókhoz (public olvasás, admin írás)
  03-auto-visszaigazolo-trigger.sql  Auto visszaigazoló + csapat-értesítő trigger + pg_net (a Database Webhook SQL-alternatívája; <PROJECT_REF>/<ANON_KEY> kitöltendő)
  04-emlekezteto-cron.sql   Napi emlékeztető pg_cron + pg_net (másnapi jóváhagyott foglalásoknak; join az idopontok táblára; <PROJECT_REF>/<ANON_KEY> kitöltendő)
  m_05-rovid-leiras.sql     Dev-migráció: rovid_leiras mező (már a 01-ben is benne)
  m_06-naptar-nezet.sql     Dev-migráció: settings.naptar_nezet (már a 01-ben is benne)
  m_07-tobb-idopont.sql     Dev-migráció: „több időpont" átállás (idopontok tábla, bookings.workshop_id→idopont_id, nézet/trigger/RLS). Üres dev-DB-hez; a végleges a 01-ben van. Később törölhető.
  t_start-programok.sql     Technikai: induló (kb. éles) programok + időpontjaik (RESET-tel)
  t_seed-demo-foglalasok.sql  Technikai (CSAK dev): demó programok/időpontok/foglalások (MINDENT töröl + újratölt). Éles DB-n NE fusson.
  t_reset-ures-allapot.sql  Technikai: minden program+időpont+foglalás törlése (üres induló állapot)
web/                        Frontend (ezt szolgálja ki a szerver / Hostinger)
  index.html                Publikus FŐOLDAL (hero-slideshow, workshopok, élmény, rólunk, programok+foglalás, kapcsolat+térkép, lábléc)
  css/style.css             Publikus stílus (sötét "parázs" paletta, tartalom max 1880px / hero max 1920px, reszponzív)
  css/dialog.css            Közös felugró ablak stílusa
  js/config.js              Supabase Project URL + anon kulcs (publikus, RLS véd)
  js/dialog.js              Saját felugró ablak (alert/confirm helyett)
  js/util.js                Publikus segédek (dátum, HUF, tisztítók, validáció) — lásd docs/js-modulok.md
  js/app.js                 Publikus: adat + programok kirajzolása (programonként csoportosítva, időpont-csempék)
  js/foglalas.js            Publikus: foglalási ablak (foglalás a kiválasztott időpontra)
  kepek/                    Főoldali képek: logo-mark.png (logó, favicon), hero-1..3.jpg (hero-slideshow), csapat.jpg (Rólunk), *_workshop.jpg + leanybucsu.jpg (workshop-boxok)
  admin/index.html          Admin oldal (belépés + fülek + modalok)
  admin/admin.css           Admin stílus
  admin/js/                 Admin logika 6 modulra bontva (util, core, foglalasok, programok, naptar, beallitasok) — lásd docs/js-modulok.md
supabase/functions/send-email/index.ts  E-mail küldő Edge Function (Deno + RESEND → email_log). Beállítás: docs/email.md, install.html
docs/                       Élő dokumentáció (ez a mappa: funkcio-, technikai-dokumentacio, email.md)
fejlesztesi-terv.md         A terv / roadmap
foglalasi-rendszer-terv.html  Ügyfél-facing áttekintő (bemutató)
felmeres-kerdessor.html/.pdf  Az ügyféligény-felmérés
start-szerver.bat           Helyi szerver indító (localhost:5500)
.github/workflows/keepalive.yml  GitHub Actions: 3 naponta pingeli a Supabase REST-et (az ingyenes projekt ne aludjon el); 2 secret kell: SUPABASE_URL, SUPABASE_ANON_KEY
```

## 3. Adatbázis

### Táblák

**`workshops`** — programok (a program KÖZÖS adatai, minden időpontra)
`id` (uuid, PK) · `cim` · `rovid_leiras` (rövid, a kártyán, kötelező) · `leiras` (részletes, **opcionális**, a „Részletek" ablakban) · `eloado` (előadó(k), opcionális; a kártyán „Előadó: …") · `varhato_idotartam` · `foto_url` · `statusz` (`aktiv`/`hamarosan`) · `archivalt` (bool) · `created_at`
Az ár/időpont/létszám NEM itt van, hanem **időpontonként** az `idopontok` táblában.

**`idopontok`** — egy program meghirdetett alkalmai (a több-időpont lelke)
`id` (uuid, PK) · `workshop_id` (FK→workshops, `on delete cascade`) · `idopont` (timestamptz) · `ar` · `kedvezmenyes_ar` (opcionális) · `max_letszam` (>0) · `statusz` (`aktiv`/`elmaradt` — egy alkalom lemondható a többi megtartása mellett) · `created_at`
Megszorítások: akciós ár < alap ár; létszám>0.

**`bookings`** — foglalások (mindig egy KONKRÉT IDŐPONTRA)
`id` (uuid, PK) · `azonosito` (bigint identity, **1-től**) · `idopont_id` (FK→idopontok, `on delete restrict`) · `nev` · `email` · `telefon` · `letszam` (>0) · `megjegyzes` · `statusz` (`jovahagyasra_var`/`jovahagyott`/`elutasitott`/`lemondott`) · `created_at`
Indexek: idopont_id, statusz, azonosito (egyedi).

**`settings`** — egysoros (id=1)
`levelezesi_email` (a **csapat** címe — ide megy a `csapat_ertesito` ÉS ez a vendég-levelek Reply-To-ja; NEM a feladó, az a `MAIL_FROM` secret) · `foglalas_infosav` · `azonosito_elotag` (≤2 kar) · `azonosito_kezdo` (1–999) · `updated_at`

**`email_sablonok`** — e-mail sablonok
`tipus` (PK: `visszaigazolas`/`csapat_ertesito`/`jovahagyas`/`elutasitas`/`lemondas`/`program_elmarad`/`emlekezteto`) · `targy` · `torzs` · `updated_at`
Behelyettesíthető mezők: `{nev} {email} {telefon} {program} {idopont} {letszam} {azonosito}`.

**`email_log`** — kiküldött levelek naplója (tartalom nélkül)
`id` (bigint, PK) · `booking_id` (FK→bookings, `on delete cascade`) · `tipus` · `cimzett` · `elkuldve`

**`oldal_statisztika`** — látogatás-számláló, egysoros (id=1)
`id` · `latogatasok` (bigint) · `updated_at`. RLS mögött, közvetlenül nem érhető el — csak a lenti függvényeken át.

### Nézet, függvények, triggerek
- **`programok`** (nézet): **program × időpont** (LEFT JOIN, hogy az időpont nélküli „hamarosan" program is látsszon), időpontonkénti `szabad_helyek`-kel. Oszlopok: `workshop_id`, `cim`, `rovid_leiras`, `leiras`, `eloado`, `varhato_idotartam`, `foto_url`, `archivalt`, `program_statusz`, `idopont_id`, `idopont`, `ar`, `kedvezmenyes_ar`, `max_letszam`, `idopont_statusz`, `szabad_helyek`. Ezt olvassa a publikus oldal, majd **programonként csoportosítja** (egy kártya, több időpont-csempe).
- **`foglalt_helyek(uuid)`** (függvény, `security definer`): egy **IDŐPONT** foglalt helyeinek száma (a `jovahagyasra_var` + `jovahagyott` foglalások létszám-összege). Anon is hívhatja, de a foglalási sorokat nem látja.
- **`ellenoriz_szabad_hely()`** + **`trg_szabad_hely`** trigger (bookings, before insert/update): túlfoglalás elleni védelem **időpont-szinten**; **elmaradt** időpontra vagy nem-aktív/archivált programra nem enged foglalni; a **publikus (anon) foglalást múltbéli időpontra elutasítja** (a mai nap még OK; az admin/seed rögzíthet historikusat).
- **`latogatas_rogzites()` / `latogatas_szam()`** (`security definer`): a látogatásszám növelése ill. olvasása. Anon is hívhatja (a tábla RLS-e miatt csak ezeken át).
- **`trg_uj_foglalas_email()`** + **`trg_uj_foglalas_email`** trigger (bookings, after insert) — **külön fájl (`db/03-auto-visszaigazolo-trigger.sql`), projekt-specifikus értékkel:** új `jovahagyasra_var` foglaláskor `pg_net`-tel meghívja a `send-email` függvényt (auto visszaigazoló + csapat-értesítő). A Supabase Database Webhook SQL-alternatívája; ugyanazt a `{type:INSERT, record}` payloadot küldi.
- **`pg_cron` napi feladat** (`kemence-napi-emlekezteto`, `db/04-emlekezteto-cron.sql`) — `pg_net`-tel a másnapi jóváhagyott foglalásoknak emlékeztetőt küld.

### Szabad helyek és azonosító képletei
- **Szabad helyek (időpontonként):** `idopontok.max_letszam − (az adott időpont `jovahagyasra_var` + `jovahagyott` létszámai)`. Az `elutasitott`/`lemondott` felszabadít.
- **Megjelenített azonosító:** `azonosito_elotag + (bookings.azonosito + azonosito_kezdo − 1)`. Alap: `F-` + 100 → `F-100`.

### Storage
- **`program-fotok`** bucket (publikus olvasás, admin írás) — ide töltődnek a program-fotók; a `workshops.foto_url` a publikus URL-t tárolja.

### Biztonság (RLS)
| Tábla | Publikus (anon) | Admin (authenticated) |
|---|---|---|
| workshops | olvas | mindent |
| idopontok | olvas | mindent |
| bookings | csak beküld (statusz='jovahagyasra_var') | olvas/módosít/töröl |
| settings | olvas | mindent |
| email_sablonok | — | mindent |
| email_log | — | olvas (írás service-role-lal) |
| oldal_statisztika | — (csak függvényen át) | — (csak függvényen át) |

Egyetlen admin fiók (Supabase Auth), **önregisztráció nincs** — a fiókot a gépházban hozzuk létre. Jelenleg minden bejelentkezett = admin.

## 4. Konvenciók

- **`db/01-schema.sql` az egyetlen igazságforrás** — mindig a teljes, friss sémát tartalmazza; üres/éles telepítéshez elég ezt lefuttatni. A storage/automatika külön fájlokban van (`02-storage.sql`, `03-auto-visszaigazolo-trigger.sql`, `04-emlekezteto-cron.sql`).
- **`db/` fájl-elnevezés:** base `01–04` (friss telepítés) · `m_` = dev-migráció (meglévő dev-DB patch-elése; később beolvad a 01-be, majd törölhető) · `t_` = technikai, újrahasználható eszköz (seed/reset). Részletek: `memory` + a fájlok fejlécei.
- **Nincs böngésző-`alert`/`confirm`/`prompt`** — minden felugró a saját `web/js/dialog.js` (`dialog.megerosit` / `dialog.uzen`).
- **Nincs placeholder ("árnyékszöveg")** a beviteli mezőkben.
- **Design:** v2 minta elrendezése + v1 minta sötét parázs-palettája; a foglalás/admin naptár-jellegű. Betűk: Fraunces + Hanken Grotesk + Space Mono.
- **Fejlesztés `http://localhost`-ról** (nem `file://`) — az auth a böngésző tárolóját használja, ami `file://` alól nem működik jól.

## 5. Futtatás

- **Helyi szerver:** `start-szerver.bat` (dupla katt) → `http://localhost:5500/` (publikus), `/admin/` (admin).
- **Adatbázis:** a `db/*.sql` fájlokat a Supabase **SQL Editor**ban futtatjuk.
  - **Éles/üres telepítés:** elég a **`01-schema.sql`** (mindig a teljes, friss séma: táblák, RLS, nézet, túlfoglalás-trigger, 7 sablon, alap-beállítások, látogatás-számláló). Utána: Storage bucket (`db/02-storage.sql` vagy UI), majd az **e-mail-automatika** (`db/03-auto-visszaigazolo-trigger.sql` + `db/04-emlekezteto-cron.sql` — ezekbe a `<PROJECT_REF>`/`<ANON_KEY>` kitöltendő, és kell `pg_net`/`pg_cron`). A teljes menetrend: **`install.html`**.
  - **Demó-adat (dev):** a `db/t_seed-demo-foglalasok.sql` mindent töröl + újratölt (programok, időpontok, foglalások). Éles adatbázison NE fusson. Üres állapothoz: `db/t_reset-ures-allapot.sql`.
  - Az **e-mail-automatika NINCS a 01-ben** (projekt-specifikus `<PROJECT_REF>`/`<ANON_KEY>` kell hozzá) — külön a `db/03-auto-visszaigazolo-trigger.sql` és `db/04-emlekezteto-cron.sql`.
- **Levélküldés:** a `send-email` Edge Function deploy + a `RESEND_API_KEY` / `MAIL_FROM` (és fejlesztésben `DEV_REDIRECT_TO`) secretek. Lásd `docs/email.md`, `install.html`.
- **Config:** a `web/js/config.js`-be kell a Supabase **Project URL** és **anon** kulcs (Settings → API).
