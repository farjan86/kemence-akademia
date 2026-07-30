# Kemence Akadémia — Felhasználói kézikönyv

> A rendszer teljes, felhasználó- és admin-szemszögű leírása. Ebből a dokumentumból közvetlenül
> generálható a felhasználói kézikönyv. Utolsó frissítés: 2026-07-30.

A rendszer két részből áll:
- **Publikus oldal** (`/`) — a vendégek itt böngészik a programokat és foglalnak.
- **Admin felület** (`/admin/`) — a csapat itt kezeli a foglalásokat, programokat, beállításokat.
  Az adatok a Supabase adatbázisban vannak; a felület mindig élő adatot mutat.

---

## 1. Fogalmak és értékkészletek

Az egész rendszer megértéséhez ezeket érdemes tudni.

### 1.1 A foglalás státusza (4 érték)
Minden foglalásnak pontosan egy státusza van. Ez határozza meg, mi a teendő vele.

| Státusz | Szín | Jelentés | Foglal helyet? |
|---|---|---|---|
| **Jóváhagyásra vár** | 🟠 narancs | Új foglalás, még nem fizetett/nem hagyták jóvá | **Igen** |
| **Jóváhagyott** | 🟢 zöld | A csapat jóváhagyta (pl. az utalás megérkezett) | **Igen** |
| **Elutasított** | 🔴 piros | A csapat elutasította (pl. nem fizetett) | Nem (felszabadul) |
| **Lemondott** | ⚪ szürke | Lemondva (a vendég jelezte, vagy a program elmaradt) | Nem (felszabadul) |

- **Helyet foglal:** a *jóváhagyásra vár* és a *jóváhagyott* foglalás **csökkenti a szabad helyeket**. Már az új (kifizetetlen) foglalás is „lefoglalja" a helyet.
- **Felszabadít:** az *elutasított* és a *lemondott* foglalás **visszaadja** a helyet.
- A *jóváhagyásra vár* és *jóváhagyott* a **„élő" foglalás**; az *elutasított* és *lemondott* a **lezárt** (végleges) állapot.

### 1.2 A program állapota (`statusz`, 3 érték)
| Állapot | Jelentés |
|---|---|
| **Aktív** | Normál, **foglalható** program (van ár, időpont, létszám). |
| **Hamarosan** | Beharangozott, **még nem foglalható** (elég a cím + leírás). |
| **Elmaradt** | A program **lemondva** (elmarad); a foglalásai „lemondott"-ra kerültek. |

### 1.3 Archivált (igen/nem) — külön dimenzió
Az **`archivált`** jelző FÜGGETLEN a program állapotától, és azt jelenti: **látszik-e a főoldalon**.
- **Nem archivált** → megjelenik a főoldalon (az „Aktuális programok" fülön).
- **Archivált** → lekerült a főoldalról, de az adatok/foglalások megmaradnak (az „Archivált programok" fülön).

➡️ Egy program lehet **egyszerre archivált ÉS „aktív" jellegű** — az „aktív" azt jelenti, *rendes program volt*, az „archivált" azt, *levettük a főoldalról*.

### 1.4 Időállapot (levezetett, a program dátumából)
| Időállapot | Jelentés |
|---|---|
| **Jövőbeli** | A program napja a jövőben van. |
| **Ma** | A program a mai napon van (kiemelve). |
| **Múltbéli / Lezárult** | A program napja már elmúlt. |

*(„Jövőbeli", nem „Közeledő" — mert egy elmaradt program is lehet jövőbeli dátumú.)*

### 1.5 Foglalási azonosító
Minden foglalás kap egy azonosítót, pl. **`F-100`**. A formátum a Beállításokban állítható (előtag + kezdő sorszám).

---

## 2. Publikus oldal (a vendég szemszögéből)

### 2.1 A főoldal felépítése
- **Hero:** teljes szélességű, 3 kép filmszerű váltakozásával + bemutatkozó szöveg és gombok.
- **Workshopjaink:** az 5 workshop-típus bemutatása (Pizza, Burek, Kovászos tészták, Leánybúcsú, Bejgli [Hamarosan]).
- **Milyen egy nap nálunk?:** az élmény bemutatása.
- **Rólunk:** a filozófia + csapatkép.
- **Programok:** az élő, foglalható programok (lásd lentebb).
- **Kapcsolat:** cím + e-mail + telefon + beágyazott Google-térkép.
- **Lábléc:** linkek (Facebook, mobilkemence.xyz, webshop, adatvédelem) + egy nem feltűnő **látogatás-számláló** (böngészőnként 6 óránként max. 1 új látogatás).

### 2.2 A program-kártyák
- **Csak a nem archivált** programok jelennek meg.
- Kártyánként: fotó (ha van), cím, rövid leírás-előnézet, időpont, várható időtartam, ár.
- **„Részletek" gomb:** a hosszú leírás külön ablakban nyílik meg (nem terheli a kártyát).
- **Szabad helyek** kiírva; ha nincs, **„Betelt"** (a gomb letiltva).
- **Kedvezményes ár:** az eredeti áthúzva, a kedvezményes kiemelve.
- **„Hamarosan" program:** csak cím + leírás + jelvény, nem foglalható.
- **„Lezárult" program:** ha a program napja már elmúlt, a kártyán „Lezárult" és a gomb letiltva (akkor is, ha még nincs archiválva). A mai nap még foglalható.

### 2.3 Hogyan foglal a vendég?
1. A programnál a **„Foglalás →"** gombra kattint.
2. Kitölti az űrlapot: **név, e-mail, telefon, létszám, megjegyzés** (a megjegyzés nem kötelező).
3. **Validáció** (hibás adattal nem küldhető el):
   - e-mail: formátum-ellenőrzés + elgépelés-figyelmeztetés (pl. `gmail.coom` → „Talán gmail.com?");
   - telefon: bármilyen formátum megengedett, a mentett érték `+36…`-ra normalizálódik;
   - létszám: legalább 1 és legfeljebb a szabad helyek száma.
4. Egy **info-sáv** tájékoztat (pl. az előre utalásról) — ennek szövege az adminban állítható.
5. Beküldés után a foglalás **„jóváhagyásra vár"** állapotban jön létre, a vendég **sikerképernyőt** lát, és **azonnal kap egy visszaigazoló e-mailt**. A szabad helyek azonnal csökkennek.

---

## 3. Admin — belépés
- Az `/admin/` címen **e-mail + jelszó** (Supabase Auth).
- **Nincs önregisztráció** — az admin fiókot a Supabase-ben hozzuk létre. Ugyanaz az e-mail cím léphet be, ami a levelezésre szolgál.
- A felület három fület tartalmaz: **Foglalások · Naptár · Programok · Beállítások**, és mobilon is jól használható (nem kell natív app).

---

## 4. Admin — Foglalások kezelése

### 4.1 A táblázat
Oszlopok: **azonosító** (pl. `F-100`) · **program** (cím + időpont) · **időállapot** · **vendég** (név, telefon, e-mail, kiment levelek) · **létszám** · **megjegyzés** · **státusz** · **művelet**.

- **Rendezés:** a foglalás ideje szerint csökkenő (legújabb felül); státuszváltáskor a sor nem ugrál.
- **Státusz-fülek:** **Jóváhagyásra vár** *(számlálóval)* · **Jóváhagyott** · **Elutasított** · **Lemondott**. A foglalás a státuszának megfelelő fülön jelenik meg; státuszváltáskor automatikusan átvándorol.
- **Szűrők a fülön belül:** program (cím + időpont; csak azok a programok, amelyekre az adott fülön van foglalás) · vendég neve (keresés) · időállapot.
- **Megjegyzés oszlop:** ha van megjegyzés, egy **📝 ikon** jelenik meg → rákattintva elolvasható.
- Ha a foglalás **archivált** vagy **elmaradó** programhoz tartozik, a program neve mellett „archivált"/„elmarad" jelölés látszik.

### 4.2 Hogyan hagyok jóvá egy foglalást?
1. Menj a **„Jóváhagyásra vár"** fülre.
2. A foglalás során nyomd meg a **„Jóváhagyás"** gombot.
3. A foglalás **„jóváhagyott"** lesz, és átkerül a **„Jóváhagyott"** fülre. A helyfoglalás megmarad.

**Mit tehetsz utána egy jóváhagyott foglalással?**
- **„✉ Levél"** → kiküldheted a **Jóváhagyás** értesítőt a vendégnek (előnézettel, szerkeszthetően — lásd 4.6).
- **„Vendég lemondta"** → ha a vendég mégis lemond (lásd 4.4).
- **„Jóváhagyás visszavonása"** → visszaállítja „jóváhagyásra vár"-ra (megerősítést kér; ha közben betelt a program, a rendszer jelzi és nem engedi).
- **„Szerkesztés"** → az adatok módosítása (lásd 4.5).

### 4.3 Hogyan utasítok el egy foglalást?
1. A **„Jóváhagyásra vár"** fülön a foglalásnál nyomd meg az **„Elutasítás"** gombot.
2. A rendszer **megerősítést kér** („az elutasított foglalás nem hozható vissza").
3. Jóváhagyás után a foglalás **„elutasított"** lesz, és a **helyek felszabadulnak**.
4. Ez **végleges** állapot — nincs több művelet rajta (de a **„✉ Levél"** gombbal küldhetsz Elutasítás-értesítőt).

### 4.4 Hogyan mondok le egy foglalást (a vendég jelezte)?
1. A foglalásnál (jóváhagyásra vár VAGY jóváhagyott soron) nyomd meg a **„Vendég lemondta"** gombot.
2. A rendszer **megerősítést kér** („a lemondott foglalás nem hozható vissza").
3. Jóváhagyás után a foglalás **„lemondott"** lesz, és a **helyek felszabadulnak**.
4. Ez **végleges** állapot — nincs több művelet (de a **„✉ Levél"** gombbal küldhetsz Lemondás-értesítőt).

> Fontos: a **„Vendég lemondta"** a *vendég* általi lemondás rögzítése — NEM a teljes program elmaradása. A teljes program lemondását a **Programok fül „Elmarad a program"** funkciója kezeli (lásd 6.4).

### 4.5 Foglalás szerkesztése
1. A soron nyomd meg a **„Szerkesztés"** gombot.
2. Egy adatlap nyílik, ahol módosítható: **program/időpont** (legördülő), **név, e-mail, telefon, létszám, megjegyzés**.
3. Mentéskor a **túlfoglalás-védelem** érvényes: ha a választott programon nincs elég szabad hely, a rendszer jelzi és nem menti.

### 4.6 Levél küldése a vendégnek (kézi) — „✉ Levél" gomb
- A **„✉ Levél"** gomb a **műveletek utolsója**, és **NEM jelenik meg a „jóváhagyásra vár" soron** (ott a vendég már megkapta a foglaláskori visszaigazolót).
- A **foglalás státusza határozza meg a sablont:** jóváhagyott → **Jóváhagyás**, elutasított → **Elutasítás**, lemondott → **Lemondás**.
- Kattintásra **előnézeti/szerkeszthető ablak** nyílik: a sablon behelyettesített tárggyal + törzzsel. **Küldés előtt szabadon módosíthatod.**
- A **„Küldés"** gombbal megy ki. Siker után a sorban a „✉ N kiment levél" számláló nő.

### 4.7 Kiment levelek megtekintése
Minden soron a **„✉ N kiment levél"** link → külön ablak listázza, milyen levelek mentek ki ehhez a foglaláshoz (típus + időpont; a tartalmat nem tárolja).

---

## 5. Admin — Naptár (éves nézet)
- Egy képernyőn a **12 hónap kártyaként**; fent **év-léptető** (‹ / ›) + **„Idén"** gomb. Az aktuális hónap kiemelve, az üres hónapok halványan.
- Minden hónap-kártyán az adott hónap programjai sorként: **nap · cím · telítettség** (pl. `16. · Kovászos kenyér · 6/8`).
- **Telítettség = az élő foglalások** (vár + jóváhagyott) létszám-összege a max létszámból. A sor színe: van hely (zöld) · közel tele ≥75% (narancs) · **betelt** (piros); az elmaradó program áthúzva.
- **Évi összesítő** a fejlécben: hány program · összes foglalt/összes hely · hány betelt.
- **Programra kattintva** a naptár alatt megnyílik az adott program **analitikája**: foglalt/szabad hely, jóváhagyva/vár (fő), majd az **élő jelentkezők listája** (azonosító · vendég · fő · státusz). A foglalások kezelése a Foglalások fülön történik.
- Csak **időponttal rendelkező** programok kerülnek a naptárba (a „Hamarosan" nem).

---

## 6. Admin — Programok kezelése
Két al-fül: **Aktuális** (aktív + hamarosan, nem archivált) és **Archivált**.

**Kártya-jelvény:** az Aktuális fülön **Aktív** vagy **Hamarosan**; az Archivált fülön **Elmarad** (ha elmaradt) vagy **Archivált** (minden más).

### 6.1 Hogyan viszek fel új programot?
1. Az **Aktuális** al-fülön nyomd meg a **„+ Új program"** gombot → megnyílik a szerkesztő.
2. Töltsd ki a mezőket:
   - **Állapot:** *Aktív* (foglalható) vagy *Hamarosan* (csak megjelenik).
   - **Cím**
   - **Részletes leírás** (hosszú is lehet — ez jelenik meg a „Részletek" ablakban).
   - **Ár (Ft)** és **Kedvezményes ár** (opcionális; kisebb kell legyen az alap árnál — áthúzva jelenik meg).
   - **Időpont** (dátum + óra:perc).
   - **Várható időtartam** (opcionális, pl. „~4 óra").
   - **Max létszám**.
   - **Fotó** (opcionális; feltöltés, előnézettel).
3. **Kötelező mezők:** *Aktív* programnál **ár + időpont + max létszám** kötelező; *Hamarosan*-nál elég a **cím + leírás**.
4. **Mentés.** *(Az ablak csak a Mentés/Mégse gombokra záródik — kattintással/Esc-cel nem, hogy ne vesszen el a kitöltött adat.)*

### 6.2 Program szerkesztése
- Az **Aktuális** fülön a **„Szerkesztés"** gomb. Bármelyik adat/fotó módosítható.
- **Ha a programra már van foglalás,** a rendszer figyelmeztet mentés előtt (a módosítás érinti a jelentkezőket).

### 6.3 Mit jelent az archiválás, és mi a következménye?
Az **archiválás** leveszi a programot a főoldalról, de **az adatai és a foglalásai megmaradnak** (megőrzi az analitikát). Az archivált program az „Archivált" al-fülre kerül.

Az archiválás menete attól függ, van-e **élő foglalás** (vár/jóváhagyott):
- **Nincs élő foglalás** (vagy múltbéli program): egyszerű megerősítés → archiválás. A foglalások változatlanok.
- **Jövőbeli/mai program élő foglalással:** a rendszer **választást** ad:
  - **„Archiválás"** → csak leveszi a főoldalról, a foglalásokat **nem bántja**.
  - **„Elmarad a program"** → lásd 6.4.

### 6.4 Hogyan mondom le a teljes programot? — „Elmarad a program"
Ha egy meghirdetett program mégsem lesz megtartva:
1. Programok → a programnál **Archiválás** → a választóból **„Elmarad a program"**.
2. **Következmény:** az élő foglalások (vár + jóváhagyott) **„lemondott"** státuszba kerülnek, a **program** pedig **„elmaradt"** állapotot kap és archiválódik.
3. A rendszer **rákérdez:** *„Kiküldjük az elmaradás-értesítőt a X vendégnek?"* (Igen / Most nem).
4. **„Igen"** esetén a rendszer **ténylegesen kiküldi** minden érintett vendégnek a *Program elmarad* levelet, és a végén jelzi, hány ment ki.

> **Múltbéli (lezajlott) programnál NINCS „Elmarad a program" opció** — ami már megtörtént, nem tud elmaradni. Ilyenkor csak sima archiválás választható.

### 6.5 Program visszaállítása (archiváltból)
- Az **Archivált** fülön a **„Visszaállítás"** gombbal. Választható, hogy **Aktív** vagy **Hamarosan** állapotban jöjjön vissza (Aktívhoz kell ár + időpont + max létszám).

### 6.6 Program törlése
- **Törlés csak akkor lehetséges, ha a programhoz NINCS egyetlen foglalás sem** (végleges művelet).
- Ha van foglalás, törölni nem lehet → **archiválni** kell (megőrzi az adatokat).

---

## 7. Admin — Beállítások

### 7.1 Csapat e-mail cím
Kettős szerepe van:
1. **Ide érkeznek** a foglalás-értesítők (a csapat értesítése új foglalásról).
2. Ez a **válaszcím (Reply-To)** a vendégeknek menő leveleken (ha a vendég válaszol, ide fut be).

> Ez **NEM a feladó** — a feladó a küldő szolgáltató (Resend) beállított címe. Részletek: `docs/email.md`.

### 7.2 Foglalási azonosító formátuma
Előtag (max 2 karakter) + kezdő sorszám (1–999), **élő előnézettel** (pl. `F-` + 100 → `F-100`). Mentés után a foglalások azonosítói eszerint jelennek meg.

### 7.3 Foglalási info-sáv
A foglalási űrlapon megjelenő tájékoztató szöveg (pl. az előre utalásról).

### 7.4 E-mail sablonok
Lásd a 8. fejezetet.

---

## 8. E-mail rendszer — hogyan működik (minden típus)

A rendszer a **Resend** szolgáltatáson át küld. Minden kiküldött levél naplózódik (a foglalásnál „✉ N kiment levél"). A koncepció és a beállítás: `docs/email.md`.

### 8.1 A 7 e-mail sablon
Az admin **Beállítások → E-mail sablonok** alatt szerkeszthető (tárgy + törzsszöveg, külön menthető):

| Sablon | Mikor / kinek |
|---|---|
| **Visszaigazolás** | foglaláskor, a vendégnek (automatikus) |
| **Csapat-értesítő** | foglaláskor, a csapatnak (automatikus) |
| **Jóváhagyás** | kézzel, a vendégnek (a „✉ Levél" gombbal) |
| **Elutasítás** | kézzel, a vendégnek |
| **Lemondás** | kézzel, a vendégnek |
| **Program elmarad** | program-elmaradáskor, az érintett vendégeknek (csoportos) |
| **Emlékeztető** | a program előtti napon, a jóváhagyott vendégeknek (automatikus, ütemezett) |

**Behelyettesíthető mezők** a tárgyban/törzsben: `{nev} {email} {telefon} {program} {idopont} {letszam} {azonosito}`.

### 8.2 A négy küldési mód
1. **Automatikus, foglaláskor:** amikor a vendég foglal, magától kimegy a **Visszaigazolás** (neki) + a **Csapat-értesítő** (nektek). *(Beállítás: `install.html` — foglalás-webhook/trigger.)*
2. **Kézi, a Foglalások fülön:** a **„✉ Levél"** gomb a státusznak megfelelő levelet küldi (Jóváhagyás / Elutasítás / Lemondás), előnézettel, szerkeszthetően (4.6).
3. **Csoportos, program-elmaradáskor:** az **„Elmarad a program"** folyamat kiküldi a *Program elmarad* levelet az érintett vendégeknek (6.4).
4. **Napi emlékeztető:** minden nap kimegy az **Emlékeztető** a **másnapi, jóváhagyott** foglalásoknak. *(Beállítás: `install.html` — pg_cron.)*

### 8.3 Ki a feladó, ki a címzett?
- **Feladó (From):** mindig a beállított küldő cím (a `MAIL_FROM`).
- **Vendég-levelek:** címzett = a vendég; válaszcím = a **Csapat e-mail cím** (a vendég válasza a csapathoz fut be).
- **Csapat-értesítő:** címzett = a **Csapat e-mail cím**; válaszcím = a vendég (a csapat egy „Válasz"-szal a vendégnek írhat).

---

## 9. Közös / UX
- **Saját felugró ablakok** minden megerősítéshez/üzenethez (nincs böngésző-popup).
- **Túlfoglalás-védelem** mindenhol: a rendszer nem enged több foglalást, mint a max létszám.
- **Reszponzív**, sötét „parázs" dizájn; mobilon is használható.

---

## 10. Tervezett (még NEM működik)
- **Excel- és PDF-export** a foglalásokról.
- **Keep-alive ping** (hogy az ingyenes Supabase ne aludjon el).
- **Főoldali képek** admin-feltöltéssel (jelenleg fix képek a `web/kepek/` mappában).
