# Kemence Akadémia — Funkció-dokumentáció

> Ez a fájl **mindig a jelenleg működő funkciókat** írja le, felhasználó/admin szemszögből.
> Amit még nem építettünk meg, a „Tervezett" szakaszban van. Utolsó frissítés: 2026-07-29.

## 1. Publikus oldal (`/`)

**Program-lista**
- A programok az adatbázisból töltődnek (`programok` nézet), minden betöltéskor frissen. **Csak a nem archivált** programok jelennek meg.
- Kártyánként: **fotó** (ha van feltöltve), cím, rövid leírás-előnézet, időpont, várható időtartam, ár.
- **Részletek:** a hosszú részletes leírás nem terheli a kártyát — a kártyán csak rövid előnézet látszik, a **teljes leírás a „Részletek" gombbal**, saját (görgethető) ablakban nyílik meg.
- **Szabad helyek** megjelenítése; ha nincs, **„Betelt"** (a gomb letiltva).
- **Kedvezményes ár:** az eredeti áthúzva, a kedvezményes kiemelve.
- **„Hamarosan" program:** csak cím + leírás, jelvénnyel; nem foglalható.
- **Lezárult (múltbéli) program:** ha a program **napja már elmúlt** (a mai nap még foglalható!), a kártyán **„Lezárult"** jelenik meg és a gomb letiltva. Ez akkor is így van, ha a programot még nem archiválták. Szerveroldalon is védve: a publikus (anon) foglalás múltbéli eseményre **elutasításra kerül** (az admin/seed rögzíthet historikus adatot).

**Foglalási űrlap** (a „Foglalás" gombbal nyíló ablak)
- Mezők: **név, e-mail, telefon, létszám, megjegyzés** (a megjegyzés nem kötelező, a többi igen).
- **Validáció** — hibás adattal nem küldhető el:
  - e-mail: formátum-ellenőrzés + **elgépelés-figyelmeztetés** (pl. `gmail.coom` → „Talán gmail.com?"; másodszori küldésre elmegy);
  - telefon: bármilyen elválasztó megengedett, a mentett érték **`+36…`-ra normalizálva**;
  - létszám: ≥1 és ≤ a szabad helyek száma.
- **Info-sáv** (állítható a beállításokban): pl. az előre utalásról szóló tájékoztató.
- **Adatvédelem:** link a kandallo-futar.hu adatvédelmi oldalára (nincs külön checkbox).
- Beküldés → a foglalás **„jóváhagyásra vár"** állapotban jön létre → sikerképernyő. A szabad helyek azonnal csökkennek.

## 2. Admin oldal (`/admin/`)

**Belépés:** e-mail + jelszó (Supabase Auth). A fiókot a Supabase gépházban hozzuk létre (nincs önregisztráció).

### „Foglalások" fül
- **Táblázat oszlopai:** **azonosító** (pl. `F-100`) · program (cím + időpont) · **időállapot** · vendég (név + telefon + e-mail + kiment levelek) · létszám · **megjegyzés** · státusz · művelet.
- **Rendezés:** a foglalás ideje szerint csökkenő (legújabb felül), állandó másodkulccsal — státuszváltáskor nem ugrál.
- **Státusz-fülek:** **Jóváhagyásra vár** *(számlálóval)* · **Jóváhagyott** · **Elutasított** · **Lemondott** — a foglalás státusza szerint. Jóváhagyáskor a sor automatikusan átvándorol a megfelelő fülre. (Az archivált/elmaradt program nem külön fül — a soron jelöléssel látszik.)
- **Szűrők a fülön belül:** program (legördülő — **cím + időpont**, mert két azonos nevű program is lehet más-más időpontban; dátum szerint rendezve) · vendég neve (keresés) · időállapot. (A régi Státusz-szűrőt a fülek váltják ki.)
- **A program-szűrő fül-specifikus:** minden fülön **csak azok a programok** jelennek meg a legördülőben, amelyekre **van foglalás az adott státusszal** (pl. a „Jóváhagyásra vár" fülön nem jön fel olyan program, amire nincs jóváhagyásra váró foglalás). Fül- és státuszváltáskor automatikusan frissül.
- **Státuszok színnel:** Jóváhagyásra vár 🟠 · Jóváhagyott 🟢 · Elutasított 🔴 · Lemondott ⚪. Szűrhető státuszra. *(Az „elmaradt" NEM foglalás-státusz — az a PROGRAM állapota; program elmaradásakor a foglalások „lemondott"-ra kerülnek.)*
- Ha a foglalás **archivált** vagy **elmaradó** programhoz tartozik, a program neve mellett **„archivált" / „elmarad"** jelölés (jelen idő — mert jövőbeli program is beállítható elmaradóra). Így az analitika levezethető: egy **„lemondott"** foglalás **elmaradó programon** = program-elmaradás miatt; **normál programon** = a vendég mondta le.
- **Időállapot** (külön oszlop, szűrhető is): a program időpontja alapján **Jövőbeli / Ma / Múltbéli** (a „Ma" kiemelve). *(„Jövőbeli", nem „Közeledő" — mert egy elmaradt program is lehet jövőbeli dátumú.)*
- **Műveletek státuszonként:**
  - Jóváhagyásra vár → Jóváhagyás · Elutasítás · **Vendég lemondta**
  - Jóváhagyott → **Vendég lemondta** · Jóváhagyás visszavonása (**megerősítést kér**)
  - A **„Vendég lemondta"** és az **„Elutasítás"** is **megerősítést kér** (mindkét lezárt állapot végleges, a foglalás nem hozható vissza).
  - *(A **„Vendég lemondta"** a vendég általi lemondás rögzítése — NEM a teljes program elmaradása; azt a Programok fül „Elmarad a program" funkciója kezeli.)*
  - Elutasított / Lemondott → nincs művelet (lezárt állapot)
- **Túlfoglalás-védelem:** ha egy „vissza várra" közben már betelt, a rendszer jelzi.
- **Kiment levelek naplója:** minden sorban a **„✉ N kiment levél"** link → saját ablak listázza, milyen levelek mentek ki (típus + időpont, **tartalom nélkül**).
- **Foglalás szerkesztése:** minden soron a **„Szerkesztés"** gomb megnyit egy adatlapot, ahol módosítható a **program/időpont** (legördülő), **név, e-mail, telefon, létszám, megjegyzés**. Mentéskor a túlfoglalás-védelem érvényes (ha a választott programon nincs elég hely, jelzi).
- **Megjegyzés oszlop:** külön oszlop; ha a foglaláshoz tartozik megjegyzés, egy **📝 ikon** jelenik meg → rákattintva saját ablakban elolvasható. Ha nincs, a cella üres.

### „Naptár" fül (Foglalások és Programok között) — éves nézet
- **Egész éves rálátás:** egy képernyőn a **12 hónap kártyaként**, fent **év-léptető** (‹ / ›) + **„Idén"** gomb; alapból az aktuális év. Az **aktuális hónap** kártyája kiemelve. Az üres hónapok halványan, „— nincs program —" felirattal.
- Minden hónap-kártyán az adott hónap programjai **sorként**: **nap · cím · telítettség** (pl. `16. · Kovászos kenyér · 6/8`). Egy hónapban több program is (dátum szerint rendezve; két azonos nevű, eltérő napú is jól elkülönül).
- **Telítettség = élő foglalások** (jóváhagyásra vár + jóváhagyott) létszám-összege a max létszámból. A sor **színe** ezt jelzi: üres/van hely (semleges/zöld), közel tele ≥75% (narancs), **betelt** (piros). Az **elmaradó** program áthúzva, halványan.
- **Évi összesítő** a fejlécben: hány program · összes foglalt/összes hely · hány betelt.
- **Programra kattintva** a naptár alatt megnyílik az adott program **analitikája** (ugyanezen a fülön): foglalt/szabad hely, jóváhagyva/vár (fő), majd a **jelentkezők listája**. Itt **csak az élő foglalások** (jóváhagyott + jóváhagyásra vár) jelennek meg — a lemondott/elutasított nem, mert a naptár arról szól, ki jön ténylegesen (azonosító · vendég · fő · státusz). A foglalások *kezelése* továbbra is a Foglalások fülön történik.
- Csak **időponttal rendelkező** programok kerülnek a naptárba (a „Hamarosan", dátum nélküli programok nem).

### „Beállítások" fül
- **Általános:** **csapat e-mail cím** (ide érkeznek a foglalás-értesítők — ez a *címzett*, NEM a feladó; a feladó a beállított Gmail-postaláda, lásd `docs/email-kuldes-setup.md`); foglalási info-sáv szövege.
- **Foglalási azonosító formátuma:** előtag (max 2 karakter) + kezdő sorszám (1–999), **élő előnézettel**. Mentés után a foglalások azonosítói eszerint jelennek meg.
- **E-mail sablonok (7):** Visszaigazolás (foglaláskor, vendégnek) / Csapat-értesítő (foglaláskor, nektek) / Jóváhagyás / Elutasítás / Lemondás / Program elmarad (a vendégeknek) / **Emlékeztető (a program előtti napon, a vendégnek)** — tárgy + törzsszöveg, külön menthető. Behelyettesíthető mezők: `{nev} {email} {telefon} {program} {idopont} {letszam} {azonosito}`.

### „Programok" fül — két al-fül: Aktuális / Archivált
- **Aktuális programok** (aktív + hamarosan) = a kínálat. **Archivált programok** = a régiek/lemondottak (nem látszanak a főoldalon, de az adataik megvannak).
- **Két független dimenzió:** a **`statusz`** (Aktív / Hamarosan / Elmaradt) = a program *jellege*; az **`archivalt`** (igen/nem) = *látszik-e a főoldalon*. Ezek függetlenek → egy program lehet **archivált ÉS „aktív" jellegű** is (rendes program volt, csak levettük).
- **Kártya-jelvény fül-tudatos:**
  - **Aktuális** fülön: **Aktív** vagy **Hamarosan**.
  - **Archivált** fülön: **Elmarad** (ha a program elmaradt) vagy **Archivált** (minden más — ott nincs „Aktív", mert az félrevezető lenne).
- **Kártyák:** cím, a fenti jelvény, időpont, ár (kedvezményes áthúzva + kiemelve), foglalt/összes hely.
- **„+ Új program"** (csak az Aktuálison) → szerkesztő. Mezők: állapot, cím, részletes leírás, ár, kedvezményes ár, időpont, várható időtartam, max létszám, **fotó** (Storage-feltöltés, előnézettel).
- **Gombok:**
  - Aktuálison: **Szerkesztés** · **Archiválás** · **Törlés** (utóbbi csak ha **nincs egyetlen foglalás sem**).
  - Archiválton: **Visszaállítás** · **Törlés** (csak ha nincs foglalás).
- **Szabályok:**
  - „Aktív" programnál kötelező **ár + időpont + max létszám**; „Hamarosan"-nál csak **cím + leírás**. Kedvezményes ár < alap ár.
  - **Törlés** csak **nulla foglalásnál** (végleges). Ha van foglalás → **archiválni** kell (megőrzi az adatokat/analitikát), nem lehet törölni.
  - **Archiválás:** a program lekerül a főoldalról, a foglalások megmaradnak. Ha van **élő foglalás** (vár/jóváhagyott) egy **jövőbeli/mai** programon, a rendszer választást ad: **„Archiválás"** (a foglalásokat nem bántja) vagy **„Elmarad a program"** → az élő foglalások **„lemondott"** státuszba kerülnek, a **program** pedig **„elmaradt"** állapotot kap (és archiválódik), majd a rendszer **rákérdez**: *„Kiküldjük az elmaradás-értesítőt a X vendégnek?"* (Igen / Most nem). A tényleges küldés a `program_elmarad` sablonnal, a **levélküldő háttér bekötése után** történik (a döntés/folyamat már most működik).
  - **Múltbéli (lezajlott) programnál NINCS „Elmarad a program" opció** — ami már megtörtént, az nem tud elmaradni. Ilyenkor csak **sima archiválás** választható, a foglalások változatlanul megmaradnak.
  - **Módosításnál**, ha a programra már van foglalás → figyelmeztetés.
  - **Visszaállítás** (Archivált → Aktuális): választható, hogy **Aktív** vagy **Hamarosan** állapotban jöjjön vissza.

## 3. Közös / UX
- **Saját felugró ablak** minden megerősítéshez/üzenethez (nincs böngésző-popup).
- **Reszponzív**, sötét „parázs" dizájn; mobilon is használható (natív app nélkül).

## 4. Tervezett (még NEM működik)
- **Tényleges levélküldés** (Supabase Edge Function + Google SMTP):
  - foglaláskor **automatikus** visszaigazoló (vendég) + csapat-értesítő (nektek);
  - **kézi** „✉ Levél a partnernek" gomb a státusz-levélhez (a sablonnal);
  - a küldő a valós leveleket a naplóba (`email_log`) írja.
- **Excel- és PDF-export.**
- **Emlékeztető e-mail** a workshop előtti napon (pg_cron).
- **Keep-alive ping** (hogy az ingyenes Supabase ne aludjon el).
