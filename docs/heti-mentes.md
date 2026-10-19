# Heti adatmentés e-mailben

> Készült: 2026-10-19. Minden hétfőn reggel egy levél érkezik a csapat címére, csatolva
> táblánként egy CSV a rendszer teljes tartalmi és ügyféladatával.

---

## 1. Mit csinál

Hétfőn 6:00 körül (budapesti idő) a `backup-export` Edge Function kiolvassa a `public` séma
**összes adattáblájának minden** sorát — archivált programokat, lezárt és elutasított
foglalásokat, naplókat is —, táblánként egy CSV-t készít, az egészet **egy ZIP-be** csomagolja
(`kemence-mentes-ÉÉÉÉ-HH-NN.zip`), és egy levélben elküldi a Beállításokban megadott csapat-címre:

| CSV a ZIP-ben | Tartalom |
|---|---|
| `workshops`, `idopontok`, `eloadok`, `program_eloadok` | programok, időpontjaik, előadók és a hozzárendelések |
| `egyedi_programok` | az ajánlatkérhető egyedi programok |
| `bookings` | minden foglalás (név, e-mail, telefon, számlázási cím, létszám, státusz) |
| `ajanlatok` | minden ajánlatkérés és ajánlat (a csatolmány **fájl** nélkül; a fájl Storage-kulcsa szövegként benne van) |
| `email_log`, `ajanlat_log` | melyik foglaláshoz/ajánlathoz mikor milyen levél ment ki |
| `settings`, `email_sablonok`, `ajanlat_sablonok`, `oldal_statisztika` | beállítások, levélsablonok, látogatásszám |

A levél rövid: tárgyában a dátum és a foglalások/ajánlatok száma, törzsében a ZIP neve és mérete.
(A táblánkénti sorszámot a függvény válasza tartalmazza — `net._http_response` —, a levél nem.)

**Teljesség.** Ez a 13 tábla a `01-schema.sql` összes adattáblája — az adatbázis tartalma
hiánytalanul visszaállítható belőle. Ami **nincs** benne, mert nem adatbázis-táblában él:
- a **kép- és csatolmány-fájlok** (Supabase Storage: `program-fotok`, `ajanlat-csatolmanyok`) —
  a CSV-kben a rájuk mutató hivatkozás szerepel, a fájlt magát a Storage-ból kell külön menteni;
- az **admin belépési fiókok** (Supabase Auth) — azokat a Supabase felületén kell újra felvenni.

### CSV-formátum

UTF-8 **BOM-mal**, **pontosvessző** elválasztó, CRLF sorvég — a magyar beállítású Excel dupla
kattintással, helyes ékezetekkel nyitja. Az értékek nyersen szerepelnek (`true`/`false`,
ISO-dátum, uuid), a JSON-mezők szövegként. Ez szándékos: egy későbbi visszatöltő SQL-nek
így a legegyszerűbb.

---

## 2. Hogyan működik

```
pg_cron (hétfő 04:00 UTC)  ──►  net.http_post  ──►  backup-export függvény
                                                       ├─ service_role-lal olvassa a táblákat (lapozva, 1000 soronként)
                                                       ├─ 13 CSV → 1 ZIP a memóriában (fflate)
                                                       └─ Resend → 1 levél, 1 csatolmány
```

Ugyanaz a minta, mint a napi emlékeztetőnél (`04-emlekezteto-cron.sql` → `send-email`).

**Biztonság.** A függvényt két kulcs nyitja: az anon kulcs (a Supabase kapu JWT-ellenőrzéséhez —
ez publikus) **és** a `BACKUP_SECRET` fejléc, amit csak a cron ismer. Enélkül kívülről nem
lehet mentés-levelet kiváltani. A címzett a szerveren van rögzítve (settings), kérésben nem
adható meg.

**Személyes adat.** A levél a vendégek nevét, címét, elérhetőségét tartalmazza. A fogadó
postafiók így adattár — legyen a cég saját, védett fiókja, és ne továbbítódjon privát címre.

---

## 3. Beállítás (egyszer)

1. **Titok.** Supabase → Edge Functions → Secrets → új secret: `BACKUP_SECRET` = egy hosszú,
   véletlen szöveg (32+ karakter; pl. egy jelszógenerátorból). Írd fel, mert a 3. lépésben
   ugyanez kell. A `RESEND_API_KEY` és a `MAIL_FROM` a `send-email`-lel közös, már megvan.
2. **Függvény.** Supabase → Edge Functions → Deploy a new function → név **pontosan**
   `backup-export` → a `supabase/functions/backup-export/index.ts` teljes tartalma → Deploy.
3. **Időzítés.** `db/05-heti-mentes-cron.sql` az SQL Editorban. A fájl tetején egy
   **BEÁLLÍTÁSOK** blokk van — csak azt kell kitölteni, a többihez nem kell nyúlni:

   | Változó | Mi | Éles érték |
   |---|---|---|
   | `project_ref` | a projekt azonosítója | `gtpdqbqxkzodbantdeqk` |
   | `anon_key` | anon kulcs (Project Settings → API) | … |
   | `backup_secret` | az 1. lépésben beállított titok | … |
   | `utemezes` | cron-kifejezés, **UTC-ben** | `'0 4 * * 1'` (hétfő 6:00 nyári / 5:00 téli idő) |
   | `azonnali_teszt` | `true` → a beütemezés mellett most is elindít egyet | `false` |

   Újrafuttatható: a régi ütemezést leszedi, az újat felteszi — **az időpont módosítása is
   ennyi**: átírod az `utemezes`-t, és újrafuttatod.
4. **Címzett.** Admin → Beállítások → „Csapat e-mail cím" ki legyen töltve (az értesítők is
   erre mennek, tehát jó eséllyel már megvan).

### Teszt (nem kell hétfőig várni)

Ugyanaz a fájl, `azonnali_teszt := true` → a lefutás végén a mentés rögtön elindul (a heti
ütemezés is beáll). Pár másodperc múlva:

```sql
select created, status_code, content::text from net._http_response order by created desc limit 3;
```

`status_code = 200` és `{"ok":true,...}` → a levél elment. Ha nem: a függvény **Logs** füle
mondja meg, miért (leggyakoribb: hiányzó `BACKUP_SECRET`, üres csapat-cím, elgépelt kulcs → 401).

---

## 4. Visszaállítás a CSV-ből

A tábla-szerkezet a `db/01-schema.sql`-ben mindig megvan, tehát egy üres adatbázisba a CSV-k
visszatölthetők: Supabase → Table Editor → a tábla → **Import data from CSV** (elválasztó: `;`),
vagy `psql`-lel `\copy tabla from 'fajl.csv' with (format csv, header, delimiter ';')`.
Sorrend a hivatkozások miatt (a ZIP-ben is ez a sorrend): `workshops` → `idopontok` → `eloadok`
→ `program_eloadok` → `egyedi_programok` → `bookings` → `ajanlatok` → `email_log` → `ajanlat_log`
→ `settings` → `email_sablonok` → `ajanlat_sablonok` → `oldal_statisztika`. A `settings`,
`email_sablonok`, `ajanlat_sablonok`, `oldal_statisztika` táblákat a `01-schema.sql` már
alapértékekkel feltölti — ezeknél `update`, nem `insert` kell. Ha erre valaha szükség lesz,
érdemes hozzá egy `t_`-szkriptet írni — a CSV ehhez minden adatot tartalmaz.

---

## 5. Kikapcsolás / módosítás

- Kikapcsolás: `select cron.unschedule('kemence-heti-mentes');`
- Más időpont: a `05-heti-mentes-cron.sql` BEÁLLÍTÁSOK blokkjában az `utemezes`
  (perc óra hónap-napja hónap hét-napja, **UTC**; Budapest nyáron +2, télen +1) → újrafuttatod a fájlt.
  A fájl fejlécében rajz és példatábla van (heti 1, heti 2, munkanapokon, naponta, havonta…).
  Pl. hétfő és csütörtök: `'0 4 * * 1,4'`; fejlesztői teszthez minden nap 14:00 nyári idő: `'0 12 * * *'`.
- Más címzett: az admin Beállítások fülén a csapat-cím.

## Kapcsolódó

`docs/email.md` (Resend, secretek) · `install.html` 2.4 és 3.5 · `db/04-emlekezteto-cron.sql` (azonos minta)
