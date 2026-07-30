# Kemence Akadémia — Éles fejlesztési terv

**Verzió:** 1.0 · 2026-07-28
**Forrás:** ügyféligény-felmérés (`felmeres-kerdessor.pdf`, `ügyél igény.txt`)
**Projektmappa:** `d:\kemence-akademia`
**Korábbi, magyarázó terv:** `foglalasi-rendszer-terv.html`

---

## 1. Hatókör — mit építünk

| Rendszer | Mi lesz vele |
|---|---|
| **kemence-akademia.xyz** | Az edukációs (workshop) oldal — **újraépítjük**, beépített foglalással. Ez a projekt magja. |
| **app.minup.io** | A jelenlegi külső foglaló — **kiváltjuk**. Megszűnik a **182 €/év** díj. |
| **mobilkemence.xyz** | **Marad**, nem nyúlunk hozzá — csak linkelünk rá. |
| **kandallo-futar.hu** | Webshop — **marad**, nem nyúlunk hozzá. Linkelünk rá + az adatvédelmi oldalára. |

- A domain **marad `kemence-akademia.xyz`** (automatikusan megújul).
- Cél: edukációs oldal + foglalás **egy helyen, egységes kinézetben**, külső szolgáltató és havidíj nélkül.
- Jelenlegi költés: domainek + minup (**182 €/év**). Az új rendszer a minup díját megszünteti.

---

## 2. Architektúra és üzemeltetés

| Réteg | Megoldás |
|---|---|
| **Frontend** | Statikus HTML/CSS/JS — **Hostingeren** hostolva (ott a domain + tárhely). Nincs PHP; a böngésző beszél a Supabase-szel. |
| **Backend** | **Supabase** — Postgres + Auth (admin) + Storage (képek) + Edge Functions + pg_cron (e-mail, időzítés). |
| **E-mail** | A Supabase küldi, a domainhez tartozó **Google-postafiókon** (`akademia@mobilkemence.xyz`) keresztül — lásd 6. pont. |
| **Ébren tartás** | Külső, ingyenes **keep-alive ping** — lásd 7. pont. |

### Tulajdonjog (megerősítve): az ügyfélé minden
- A Supabase-projektet **az ügyfél regisztrálja**, én **meghívott fejlesztő** vagyok.
- A Hostinger, a domain és a DNS is az ügyfél kezében (minden a Hostingeren).
- Az ügyfél a napi munkát a mi **admin oldalunkon** végzi, nem a Supabase gépházában.

### Kétlépcsős üzemeltetés
1. **Fejlesztés / demó:** a bemutatóhoz a rendszer **az én saját Supabase-fiókomon és egy ingyenes Hostinger-fiókon** fut → az ügyfél élőben kipróbálja.
2. **Élesítés:** az ügyfél létrehozza a saját Supabase- + Hostinger-fiókját, én meghívott fejlesztőként **átköltöztetem** a projektet (adatokkal), a domaint ráállítjuk.
3. **Átadás:** minden az ügyfél nevén, a számlázás az övé, nem kötődik hozzám.

### „Megfelel a Hostinger, főleg az e-mailre?" — igen
A Hostinger csak a **statikus oldalt** szolgálja ki (ehhez bőven elég). Az **e-maileket nem a Hostinger küldi**, hanem a Supabase a Google-postafiókon át — vagyis a levélküldés **független attól**, hol van az oldal hostolva. A Hostinger megfelel.

---

## 3. Adatmodell

### Tábla: `workshops` (programok)

| Mező | Mit tárol | Kötelező? |
|---|---|---|
| `cim` | A workshop neve | Igen |
| `leiras` | Részletes leírás (hosszú szöveg, az eredeti oldal leírásai alapján) | Igen |
| `ar` | Alap (eredeti) ár, Ft | Igen* |
| `kedvezmenyes_ar` | Ha akció van — eredetit áthúzva, ezt kiemelve mutatjuk | Nem |
| `idopont` | Dátum + óra:perc (nem ismétlődő; az admin adja meg) | Igen* |
| `varhato_idotartam` | Pl. „~4 óra" | Nem |
| `max_letszam` | A hely felső korlátja | Igen* |
| `foto_url` | A program fotója (Storage-ban; az admin tölti fel) | Nem |
| `statusz` | `aktiv` (foglalható) vagy `hamarosan` (csak megjelenik) | Igen |

\* A **„hamarosan"** státuszú programnál csak a **cím és a leírás** kötelező — ár, időpont, létszám, fotó ilyenkor elhagyható.

### Tábla: `bookings` (foglalások)

| Mező | Mit tárol | Kötelező? |
|---|---|---|
| `workshop_id` | Melyik programra/időpontra szól (FK → workshops) | Igen |
| `nev` | A foglaló neve | Igen |
| `email` | **Erős validációval** (ide megy a visszaigazoló + emlékeztető) | Igen |
| `telefon` | **Alap validációval** | Igen |
| `letszam` | Hány főre szól (ennyi helyet foglal) | Igen |
| `megjegyzes` | Szabad szöveg | Nem |
| `statusz` | `jovahagyasra_var` / `jovahagyott` / `elutasitott` / `lemondott` | Igen |
| `azonosito` | **Ember-barát sorszám** (belső 1-től; megjelenítve: **előtag + (azonosito + kezdő − 1)**, alap `F-100`). A levelek tárgyába fixen bekerül. Az **előtag (max 2 karakter)** és a **kezdő sorszám (1–999)** a settingsben állítható (`azonosito_elotag`, `azonosito_kezdo`). | auto |

### Szabad helyek és státuszok
- **Szabad helyek:** `szabad = max_letszam − (jovahagyasra_var ÉS jovahagyott foglalások letszam-összege)`.
  - Már a **„jóváhagyásra vár" is lefoglalja** a helyet.
  - Az **elutasított** és a **lemondott** **felszabadítja**.
- **Másodlagos (levezetett) státusz:** a program időpontja alapján **„közeledő"** (jövőbeli), **„aznapi"** (ma van a program — se nem jövőbeli, se nem múltbéli), vagy **„múltbéli"** (nem tároljuk, a dátumból számoljuk). Az „aznapi" külön kiemelést kap az adminban (pl. saját színnel/jelöléssel).

### Beállítás: `settings`
- **Levelezési e-mail cím** (`akademia@mobilkemence.xyz`) — a `settings` táblában tárolt **beállítás**, az admin UI-n szerkeszthető. Ez a **feladó (küldő) cím**, ahonnan a levelek mennek és ahova a csapat-értesítő érkezik. A tényleges küldési kulcs (Google **App Password**) **Supabase-titok**, nem jelenik meg a felületen.
- ⚠️ Ez **NEM a belépési adat** — a belépés a Supabase Authban van (lásd 5. pont). A gyakorlatban a két cím megegyezik.
- **Foglalási info-sáv szövege** (`foglalas_infosav`) — a foglalási űrlapon megjelenő tájékoztató (pl. az előre utalásról). **Globális** beállítás (nem programonként), az admin szerkesztheti; van értelmes alapértelmezése.
- Ide kerülhet a főoldal 2–3 cserélhető képének hivatkozása is.

### Biztonsági szabályok (RLS)
- Publikus látogató: **csak olvashatja** a programokat + szabad helyeket, és **foglalást beküldhet**. A jelentkezők adatait **nem látja**.
- Minden más (foglalások listája, szerkesztés, törlés): csak a **bejelentkezett adminnak**.

---

## 4. Publikus oldal és foglalás

### Dizájnirány (az ügyfél választása)
- **v2 minta elrendezése/felépítése** + **v1 minta sötét színvilága** (korom háttér, parázs/láng akcentek) + **v1 naptáras foglaló nézete**.
- Paletta forrás (v1): `--korom #16100B`, `--brick #271B12`, `--parazs #E4571B`, `--lang #F59E1B`, `--text #F1E4D2`, `--hamu #B49E86`. Betűk: Fraunces + Hanken Grotesk + Space Mono.
- A kemence akadémia fotóit használjuk; a program-leírások az eredeti kemence-akademia.xyz szövegeiből (az admin tölti fel).

### Foglalási folyamat
1. A programkártyán a **„Foglalás" gomb** → megnyílik a **naptáras foglalási nézet**, az adott programra **előre kiválasztva**.
   - *Döntés (fejlesztőé volt): külön megnyíló űrlap-nézet, nem oldalon belüli ugrás — a v1 mintakód alapján ez a legtisztább. Könnyen váltható, ha az ügyfél az utóbbit kéri.*
2. Adatok: **név, e-mail, telefon, létszám, megjegyzés** (megjegyzés nem kötelező, többi igen). **E-mailre erős, telefonra alap** validáció — hibás adattal **nem küldhető el**.
3. **Információs sáv:** a foglalás jóváhagyáshoz **előre utalást** kér. Adatvédelem: link a **kandallo-futar.hu adatvédelmi oldalára** (`https://kandallo-futar.hu/index.php?id_cms=7&controller=cms`), külön checkbox nélkül.
4. Beküldés → foglalás **„jóváhagyásra vár"** állapotban (rögtön lefoglalja a helyet) → **azonnali visszaigazoló** a vendégnek + **csapat-értesítő**. Vagy a vendég **bezárhatja** küldés nélkül.

### További elemek
- A látogató **látja a szabad helyek számát** minden programnál.
- **Kedvezményes ár:** eredeti **áthúzva**, kedvezményes **feltűnően, csalogatóan**.
- **„Hamarosan" programok** megjelennek (cím + leírás), de nem foglalhatók.
- **Nincs** vendég/partner regisztráció. Lemondás/módosítás: a partner jelzi a csapatnak, az admin intézi.
- **Nincs galéria.** Lábléc-linkek: **Facebook-oldal**, **mobilkemence.xyz**, **kandallo-futar.hu** webshop.
- Főoldali 2–3 általános kép és a program-fotók is **admin által feltölthetők** (Storage).

---

## 5. Admin felület

Jelszavas, **egyetlen e-maillel** (`akademia@mobilkemence.xyz` = a levelezési cím). Mobilon is jól használható, **natív app nélkül**.

### Belépés (hitelesítés — Supabase Auth)
- **Egyetlen admin fiók** léphet be, e-mail = `akademia@mobilkemence.xyz`.
- Ezt az egy fiókot (e-mail + jelszó) **egyszer a Supabase gépházában** hozzuk létre — **nincs publikus regisztráció**, más nem tud fiókot csinálni.
- Ezután az admin **a mi oldalunkon** lép be (soha nem a gépházban). A **jelszóváltás / elfelejtett jelszó** beépíthető a mi admin UI-ba (Supabase `updateUser` / e-mailes reset) → onnantól a gépház nem kell.

### Beállítás (a mi admin felületünkön)
- A **levelezési e-mail cím** itt állítható — ez a **feladó cím** (a `settings` táblában), **nem** a belépési adat. A gyakorlatban ugyanaz: `akademia@mobilkemence.xyz`.

### Programkezelés
- Új program felvitel.
- Szerkesztés (bármely adat + fotó) — **figyelmeztetés, ha érvényes foglalás van rá**.
- Törlés — **figyelmeztetés, ha érvényes foglalás van rá**.

### Foglaláskezelés
- **Táblázatos nézet:** melyik programra ki foglalt — **név, telefon, e-mail, foglalt helyek, program időpontja**. A **program és időpont kiemelve**, amelyre a foglalás érkezett.
- **Státuszok színjelzéssel:** `jóváhagyásra vár` = **narancs**, `jóváhagyott` = **zöld**, `elutasított` = **piros**, `lemondott`.
- **Jóváhagyás:** minden foglalás „jóváhagyásra vár" állapotban indul → utalás után az admin **jóváhagyja**. Már a „vár" állapot is **csökkenti a szabad helyet**.
- **Elutasítás** (ha nem fizet): **felszabadítja** a helyeket.
- **Lemondás:** az admin rögzíti → „lemondott".
- **Másodlagos státusz:** közeledő (jövőbeli) / **aznapi** (ma — külön kiemelve) / múltbéli.
- **Szerkesztés:** a foglalás adatlapja megnyílik — módosítható a **név, telefon, e-mail, foglalt helyek, sőt a program vagy időpont is**.
- **„✉ Levél a partnernek" — KÉZI művelet (nem automatikus!):** az admin dönti el, mikor küld a vendégnek a státuszhoz tartozó sablonnal (jóváhagyás / elutasítás / lemondás). Így egy elkattintott jóváhagyás nem spammeli a vendéget felesleges levelekkel.
- **E-mail sablonok** (külön `email_sablonok` tábla, az admin szerkeszti): tipusonként **tárgy + törzsszöveg**, behelyettesíthető mezőkkel (`{nev}`, `{email}`, `{telefon}`, `{program}`, `{idopont}`, `{letszam}`, `{azonosito}`). A **foglalási azonosító fixen a tárgyba** kerül. Típusok: visszaigazolás (foglaláskor, vendég), csapat-értesítő (foglaláskor, nektek), jóváhagyás, elutasítás, lemondás, emlékeztető.
- **Kiment levelek naplója** (`email_log` tábla): minden sorban a **✉ „kiment levél" linkre** kattintva látszik, milyen levelek mentek ki a foglaláshoz (típus + időpont, **tartalom nélkül**). A küldő háttér írja; már a „jóváhagyásra vár" foglaláson is ott a foglaláskori visszaigazolás.

### Naptár nézet
- Havi bontású naptár a meghirdetett programokkal, mindegyiknél a **foglalt / összes** aránnyal (pl. **4/10**).

### Export
- Foglalás-analitika **Excelbe** kitehető + **PDF export** gomb.

---

## 6. E-mailek — a saját címről

Minden levél az **`akademia@mobilkemence.xyz`** címről megy.

| Levél | Mikor | Kinek / tartalom |
|---|---|---|
| Visszaigazoló | Azonnal, foglaláskor | Vendégnek — „megkaptuk a foglalásod" |
| Csapat-értesítő | Azonnal, foglaláskor | Csapatnak — **melyik workshop, milyen dátummal, hány fő** |
| Emlékeztető | A workshop **előtti napon** | Vendégnek — a foglaláskor megadott címre |
| Státusz-értesítő | **Kézi** (az admin „✉ Levél a partnernek" gombjával) | Vendégnek — a státuszhoz tartozó sablonnal; a tárgyban a foglalási azonosító |

> **Auto vs. kézi:** a **foglaláskor** a visszaigazoló (vendég) és a csapat-értesítő **automatikusan, fixen** megy mindkét félnek. A **státusz-értesítő** ezzel szemben **kézi** (az admin „✉ Levél a partnernek" gombjával) — hogy egy elkattintott jóváhagyás/visszavonás ne spammelje a vendéget.

### Hogyan megy ki
1. Esemény kiváltja: **új foglalás** (→ visszaigazoló + csapat-értesítő, **automatikus**), **kézi státuszküldés** (→ státusz-értesítő), vagy a **napi pg_cron** észleli a holnapi workshopokat (→ emlékeztető).
2. Egy Supabase **Edge Function** elküldi a levelet a **Google-postafiókon** át (SMTP, `akademia@mobilkemence.xyz`). A mobilkemence.xyz-nek **már van Google SPF-je** → hitelesített, **DNS-módosítás nélkül**.
3. Alternatíva, ha kell: levélküldő szolgáltatás (Resend/Brevo) — de a Google-fiók a napi pár levélhez elég.

> ⚠️ **Biztonság:** az `akademia@mobilkemence.xyz.txt` fájlban **nyílt szövegben ott a postafiók jelszava**. Ne kerüljön repóba/nyilvánosságra. A küldéshez dedikált **Google App Password** (2FA kell hozzá) javasolt, **Supabase-titokként** tárolva — nem a kódban.

---

## 7. Keep-alive — hogy a Supabase ne aludjon el

Az ingyenes Supabase 1 hét teljes inaktivitás után szünetel, és **nem ébred fel magától** (kézi restore kellene). Megoldás:

1. Külső, ingyenes **uptime-figyelő** (UptimeRobot / cron-job.org) rendszeresen **meghív egy Supabase-végpontot** — a látogatóktól függetlenül.
2. Ez valódi aktivitás → az óra sosem telik le, a rendszer ébren marad, 0 Ft.
3. Bónusz: **állapotjelző** — az admin láthatja, hogy fut az oldala.

> **Fontos:** a pingnek **a Supabase-t** kell kopogtatnia (nem csak a Hostinger-oldalt), mert az adatbázis alszik el, nem a statikus oldal.

---

## 8. Fejlesztési fázisok

**1. fázis — Adatbázis + admin alap**
Supabase-projekt (demóhoz a saját fiókomon), `workshops` + `bookings` táblák, RLS. Admin belépés egy e-maillel, levelezési cím beállítása. Programkezelés (felvitel/szerkesztés/törlés/fotó, figyelmeztetésekkel).
→ *Eredmény: felvihető egy program, áll az admin váza.*

**2. fázis — Publikus oldal + foglalás**
Edukációs oldal a kért dizájnban (v2 elrendezés, v1 sötét, v1 naptár). Programok az adatbázisból (szabad helyek, kedvezményes ár, „hamarosan"). Naptáras foglalási űrlap + validáció + utalás-infosáv + adatvédelmi link. Beküldés → „jóváhagyásra vár" + azonnali visszaigazoló + csapat-értesítő.
→ *Eredmény: a látogató tud foglalni, jönnek a levelek.*

**3. fázis — Teljes foglaláskezelés**
Foglalások táblázata (kiemelt program/időpont, keresés). Státuszok színjelzéssel; jóváhagyás/elutasítás/lemondás/módosítás; közeledő–múltbéli. Státusz-értesítő e-mailek. Havi naptár nézet (foglalt/összes arány); Excel- + PDF-export.
→ *Eredmény: az ügyfél végig kezeli a foglalásokat.*

**4. fázis — Emlékeztető + üzemi finomítás**
Emlékeztető e-mail a workshop előtti napon (pg_cron). Keep-alive ping + állapotjelző. Dizájn-/szövegcsiszolás, mobilnézet, teljesítmény.
→ *Eredmény: önjáró rendszer, kész a bemutatóra.*

**5. fázis — Élesítés és átadás**
Ügyfél saját Supabase- + Hostinger-fiókja; projekt átköltöztetése (adatokkal). A kemence-akademia.xyz ráállítása az új oldalra (DNS a Hostingeren), teszt valós adatokkal. Átadás: minden az ügyfél nevén.
→ *Eredmény: éles, ügyfél-tulajdonú működés.*

---

## 9. Nyitott pontok és megjegyzések

- **Google App Password:** az SMTP-küldéshez a postafiókon **2FA + App Password** kell — élesítés előtt beállítjuk, Supabase-titokként tároljuk.
- **Jelszó nyílt szövegben:** az `akademia@mobilkemence.xyz.txt` jelszava kerüljön biztonságos helyre, ne a projektmappába/repóba.
- **Foglalási űrlap UX:** külön megnyíló naptáras nézet a terv — ha az ügyfél oldalon belüli ugrást kér, váltható.
- **Excel/PDF export tartalma:** véglegesítendő, mely mezők/bontás kell az analitikába.
- **Demó egyedi domain nélkül:** a demó a Hostinger **ideiglenes aldomainjén** (pl. `*.hostingersite.com`) fut, **teljes funkcionalitással** — a logika a Supabase-ban van, URL-független. Csak a demó URL-t felvesszük a Supabase engedélyezett címei közé (CORS + Auth redirect), és kell rá HTTPS/SSL (a Hostinger az aldomainre is ad).
- **Hostinger-csomag (megerősítendő):** a statikus oldal igénye minimális (fájlkiszolgálás + SSL + domain, se PHP, se tárhelyi DB), így **bármely fizetős csomag kiszolgálja** — de a felmérésen fixáljuk az ügyfél **konkrét csomagját, korlátait és lejáratát**. Az új oldal a **meglévő kemence-akademia.xyz helyére** kerül, így nem kell új website-hely.
- **Ingyenes vs. fizetős Hostinger:** a demóhoz elég egy ingyenes/próba vagy a legolcsóbb csomag; élesben az ügyfél **meglévő, fizetős** Hostingere szolgálja ki (a mostani oldal is ott fut — az IP a HOSTINGER-HOSTING tartományból való).

---

## 10. Költség összefoglaló

| Tétel | Most | Új rendszerrel |
|---|---|---|
| minup foglaló | **182 €/év** | **0** (megszűnik) |
| Supabase | — | **0 Ft** (ingyenes csomag, keep-alive-val) |
| E-mail küldés | — | **0 Ft** (saját Google-postafiók) |
| Hostinger tárhely | (megvan) | változatlan |
| Domain | (megvan, auto-megújul) | változatlan |

**Nettó változás: −182 €/év + saját, egységes rendszer.**
