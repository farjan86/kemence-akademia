# Kemence Akadémia — Felhasználói kézikönyv

> A rendszer teljes, felhasználó- és admin-szemszögű leírása. Ebből a dokumentumból közvetlenül
> generálható a felhasználói kézikönyv. Utolsó frissítés: 2026-08-07 (Egyedi programok + Ajánlatok ág).

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

### 1.1b Az ajánlat státusza (5 érték) — az EGYEDI ág
Az **egyedi programoknál** (időpont nélküli ötletek) a vendég nem foglal, hanem **ajánlatot kér**. Az ajánlatnak külön státusz-készlete van:

| Státusz | Szín | Jelentés |
|---|---|---|
| **Ajánlatra vár** | 🟠 narancs | Új ajánlatkérés érkezett, még nincs válasz |
| **Ajánlat kiküldve** | 🟣 lila | A szervező (a rendszeren KÍVÜL, e-mailben) ajánlatot adott, várja a választ |
| **Elfogadva** | 🟢 zöld | A vendég igent mondott; rögzültek a végleges adatok (időpont, létszám, ár) |
| **Elutasítva** | 🔴 piros | Az ajánlatot elutasították |
| **Lemondva** | ⚪ szürke | Lemondva (a vendég vagy a szervező — akár elfogadás után is) |

> Az ajánlat teljesen **külön ág** a foglalástól: külön tábla, külön e-mailek, külön napló. A foglalások és az ajánlatok nem keverednek.

### 1.2 A program állapota (`statusz`, 2 érték)
| Állapot | Jelentés |
|---|---|
| **Aktív** | Normál program, amelyhez **időpontok** tartoznak (időpontonként ár + létszám). |
| **Hamarosan** | Beharangozott, **még nincs időpontja** (elég a cím + leírás); a főoldalon „Hamarosan" jelvénnyel látszik. |

### 1.2b Az időpont állapota (`idopontok.statusz`, 2 érték)
Egy programnak több **időpontja** (alkalma) lehet; mindegyiknek saját **ára, kedvezményes ára, létszáma** és opcionálisan **csoportos korlátai** (lásd 1.2c) vannak.
| Állapot | Jelentés |
|---|---|
| **Aktív** | Foglalható alkalom. |
| **Elmaradt** | Ez az **egy alkalom** elmarad (a program többi időpontja megmaradhat); új foglalás nem adható rá, az érintett foglalók lemondhatók + értesíthetők. |

### 1.2c Csoportos korlátok (időpontonként, opcionális)
Egy alkalom **csoportnak/csapatnak** szánható. Két opcionális mező az `idopontok` táblán:
| Mező | Jelentés |
|---|---|
| **`max_foglalasok`** | Hány **foglalás** (csapat) fogadható az időpontra. `1` = egyetlen csoport foglalja le az egészet. Üresen (null) = korlátlan. |
| **`min_letszam`** | Egy foglalás **legalább** ennyi fős legyen. `10` = csak 10 főtől felfelé foglalható. Üresen (null) = nincs alsó határ. |

Az időpont **automatikusan lezár** („Betelt"), ha eléri a `max_foglalasok` számát, **vagy** ha a maradék szabad hely kevesebb a `min_letszam`-nál (akkor már egy szabályos foglalás sem férne be). Megkötés: `min_letszam ≤ max_letszam`. Admin utólag módosíthatja; a minimum alá eső **meglévő** foglalásnál szerkesztéskor csak **figyelmeztetés** van, nem tiltás.

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

### 1.6 Ajánlat-azonosító
Minden ajánlatkérés kap egy azonosítót, pl. **`A-100`** — a foglalásétól **függetlenül** állítható (előtag + kezdő sorszám a Beállításokban), hogy ne keveredjen az `F-100` foglalásokkal.

---

## 2. Publikus oldal (a vendég szemszögéből)

### 2.1 A főoldal felépítése
- **Fejléc:** logó + menü, és **két gomb: „Foglalj időpontot"** (a Programokhoz ugrik) és **„Kérj ajánlatot"** (az Egyedi programokhoz). Mobilon a menü egy **hamburger (☰)** ikon mögött legördül, a két gomb megmarad.
- **Hero:** teljes szélességű, 3 kép filmszerű váltakozásával + bemutatkozó szöveg és gombok.
- **Milyen egy nap nálunk?:** az élmény bemutatása.
- **Rólunk:** a filozófia + csapatkép.
- **Programok:** az élő, foglalható programok (lásd 2.2–2.3).
- **Egyedi programok:** időpont nélküli ötletek (leánybúcsú, csapatépítő, szülinap…), amikre a vendég **ajánlatot kér** (lásd 2.4).
- **Kandalló-Futár webshop:** a kerti tűzhöz kapcsolódó termékek bemutatása + link a webshopra.
- **Lábléc:** a **kapcsolati infó** (cím, e-mail, telefon, beágyazott térkép) + linkek + egy nem feltűnő **látogatás-számláló** (böngészőnként 6 óránként max. 1 új látogatás). *(A korábbi külön „Kapcsolat" szekció megszűnt — minden infó a láblécben van.)*

### 2.2 A program-kártyák
- **Csak a nem archivált** programok jelennek meg, **programonként egy kártya** (nem időpontonként külön).
- Kártyánként: fotó (ha van), cím, **„Előadó: …"** (ha meg van adva), rövid leírás-előnézet, várható időtartam.
- **„Részletek" gomb:** a hosszú leírás külön ablakban nyílik meg (nem terheli a kártyát).
- **Időpont-csempék:** a kártya alján minden **jövőbeli** időpont egy **kattintható csempe** — rajta a **dátum, az ár és a szabad helyek**. A betelt/elmaradt csempe letiltva („Betelt" / „Elmarad"); a **múltbeli** időpontok nem jelennek meg.
- **Kedvezményes ár:** a csempén az eredeti áthúzva, a kedvezményes kiemelve.
- **„Hamarosan" program:** ha nincs jövőbeli, aktív időpontja, csak cím + leírás + „Hamarosan" jelvény, csempe nélkül.

### 2.3 Hogyan foglal a vendég?
1. A programnál **rákattint a kívánt időpont-csempére** (dátum · **ár/fő** · állapot). A csempe állapota: „N/M foglalt", csoportos alkalomnál „Min. N fő" / „Csoportos", betelt esetén „Betelt".
2. Kitölti az űrlapot: **név, e-mail, telefon, létszám, megjegyzés** (a megjegyzés nem kötelező). Csoportos alkalomnál a foglalóablak kiírja a feltételt (pl. „Csoportos alkalom: legfeljebb 1 foglalás tehető, legalább 10 fős foglalás szükséges").
3. **Validáció** (hibás adattal nem küldhető el):
   - e-mail: formátum-ellenőrzés + elgépelés-figyelmeztetés (pl. `gmail.coom` → „Talán gmail.com?");
   - telefon: bármilyen formátum megengedett, a mentett érték `+36…`-ra normalizálódik;
   - létszám: legalább 1 (vagy a beállított **`min_letszam`**), és legfeljebb a szabad helyek száma.
4. Egy **info-sáv** tájékoztat (pl. az előre utalásról) — ennek szövege az adminban állítható.
5. Beküldés után a foglalás **„jóváhagyásra vár"** állapotban jön létre, a vendég **sikerképernyőt** lát, és **azonnal kap egy visszaigazoló e-mailt**. A szabad helyek azonnal csökkennek.

### 2.4 Egyedi programok — ajánlatkérés (a vendég szemszögéből)
Az **Egyedi programok** blokk időpont nélküli ötleteket mutat (kép + cím + rövid leírás + „Részletek"). Minden kártyán egy **„Kérjen egyedi ajánlatot"** gomb.
1. A gomb megnyit egy **ajánlatkérő űrlapot** (rögzíti, melyik ötletre kér ajánlatot).
2. A vendég kitölti: **név, e-mail, telefon, létszám, kívánt időpont, „mit szeretne"** — ezen a formon **minden mező kötelező** (e-mail/telefon formátum-ellenőrzéssel).
3. Beküldés után az ajánlatkérés **„ajánlatra vár"** állapotban jön létre, a vendég **sikerképernyőt** lát, és **visszaigazoló e-mailt** kap („megkaptuk, hamarosan válaszolunk").
4. Az ár-egyeztetés a **rendszeren KÍVÜL, e-mailben** történik (a szervező személyre szabott ajánlatot küld). Az admin a rendszerben csak az **állapotot** és az elfogadáskori **végleges adatokat** rögzíti.

---

## 3. Admin — belépés
- Az `/admin/` címen **e-mail + jelszó** (Supabase Auth).
- **Nincs önregisztráció** — az admin fiókot a Supabase-ben hozzuk létre. Ugyanaz az e-mail cím léphet be, ami a levelezésre szolgál.
- A felület fülei: **Foglalások · Naptár · Programok · Egyedi programok · Ajánlatok · Beállítások**, és mobilon is jól használható (nem kell natív app).

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

### 4.5 Foglalás szerkesztése és áthelyezése
1. A soron nyomd meg a **„Szerkesztés"** gombot.
2. Módosítható: **név, e-mail, telefon, létszám, megjegyzés**, és a foglalás **áthelyezhető** ugyanazon program **másik időpontjára** (legördülő).
3. **Áthelyezés csak azonos árú időpontra** lehetséges (a legördülő csak ilyeneket kínál). Ha a másik időpont ára eltér, a vendégnek **új foglalást** kell leadnia.
4. Mentéskor a **túlfoglalás-védelem** érvényes: ha a választott időponton nincs elég szabad hely, a rendszer jelzi és nem menti.

> Hasznos, ha a szervező lemond egy időpontot és másikat ajánl, vagy ha a vendég kéri az áthelyezést.

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
- Minden **időpont külön eseményként** kerül a naptárba (az időpont nélküli „Hamarosan" program nem).
- Az **elfogadott egyedi ajánlatok** is megjelennek a naptárban (a **végleges időpontjuknál**), **lila „✨" jelöléssel**, hogy egy pillantással elkülönüljenek a foglalásoktól. Rájuk kattintva a végleges adatok (létszám, összár, vendég) látszanak; a kezelésük az **Ajánlatok** fülön történik.

---

## 6. Admin — Programok kezelése
Két al-fül: **Aktuális** (aktív + hamarosan, nem archivált) és **Archivált**.

**Kártya-jelvény:** az Aktuális fülön **Aktív** vagy **Hamarosan**; az Archivált fülön **Elmarad** (ha elmaradt) vagy **Archivált** (minden más).

### 6.1 Hogyan viszek fel új programot?
1. Az **Aktuális** al-fülön nyomd meg a **„+ Új program"** gombot → megnyílik a szerkesztő.
2. Töltsd ki a program **közös** mezőit:
   - **Állapot:** *Aktív* (időpontokkal, foglalható) vagy *Hamarosan* (csak megjelenik, időpont nélkül).
   - **Cím**, **Rövid leírás** (a kártyán), **Részletes leírás** (a „Részletek" ablakban).
   - **Előadó** (opcionális; több név vesszővel — a kártyán „Előadó: …").
   - **Várható időtartam** (opcionális, pl. „~4 óra"), **Fotó** (opcionális; feltöltés, előnézettel).
3. **Időpontok** (csak *Aktív* programnál): a **„+ Időpont hozzáadása"** gombbal annyi alkalmat veszel fel, amennyit szeretnél; időpontonként **dátum + idő, ár (fejenként), kedvezményes ár (opc.), max létszám**, és opcionálisan a **csoportos korlátok** (min. fő/foglalás, max. foglalás — lásd 1.2c). Új időpont mindig „Aktív" (az „Elmarad" csak meglévő időpontnál választható). Az ablak alján info-szöveg magyarázza a korlátokat.
4. **Kötelező:** cím + rövid leírás; *Aktív* programnál minden felvitt időpontnál **dátum + ár + max létszám**. *Hamarosan*-nál nincs időpont (a mező is eltűnik).
5. **Mentés.** *(Az ablak csak a Mentés/Mégse gombokra záródik — kattintással/Esc-cel nem.)*

### 6.2 Program szerkesztése
- Az **Aktuális** fülön a **„Szerkesztés"** gomb. Bármelyik adat/fotó módosítható.
- **Ha a programra már van foglalás,** a rendszer figyelmeztet mentés előtt (a módosítás érinti a jelentkezőket).

### 6.3 Mit jelent az archiválás, és mi a következménye?
Az **archiválás** leveszi a programot a főoldalról, de **az adatai és a foglalásai megmaradnak** (megőrzi az analitikát). Az archivált program az „Archivált" al-fülre kerül. Ha élő foglalás tartozik hozzá, a rendszer erre figyelmeztet; a foglalásokat az archiválás **nem bántja** (lemondani a Foglalások fülön lehet, vagy egy-egy időpontot „Elmarad"-ra állítani — lásd 6.4).

### 6.4 Hogyan mondok le egy időpontot? — „Elmarad"
Ha egy **konkrét alkalom** mégsem lesz megtartva (a program többi időpontja maradhat):
1. Programok → a programnál **Szerkesztés** → az érintett időpont sorában állítsd az állapotot **„Elmarad"**-ra → **Mentés**.
2. **Következmény:** arra az időpontra **új foglalás már nem adható**.
3. Ha az időpontnak volt **élő foglalása**, a rendszer rákérdez, mi legyen velük:
   - **Maradjanak** (nem mondja le) · **Lemondás értesítő nélkül** · **Lemondás + elmaradás-értesítő**.
4. A **„Lemondás + elmaradás-értesítő"** a foglalásokat „lemondott"-ra állítja, és kiküldi az érintett vendégeknek a *Program elmarad* levelet (a végén jelzi, hány ment ki).

> Ez **időpont-szintű**: egy alkalom elmaradhat, miközben a program többi időpontja megy tovább.

### 6.5 Program visszaállítása (archiváltból)
- Az **Archivált** fülön a **„Visszaállítás"** gombbal. Választható, hogy **Aktív** vagy **Hamarosan** állapotban jöjjön vissza (Aktívhoz kell ár + időpont + max létszám).

### 6.6 Program törlése
- **Törlés csak akkor lehetséges, ha a programhoz NINCS egyetlen foglalás sem** (végleges művelet).
- Ha van foglalás, törölni nem lehet → **archiválni** kell (megőrzi az adatokat).

### 6.7 Sorrend a főoldalon (húzással)
Az **Aktuális** al-fülön a program-kártyák a **⠿ fogantyúval húzva átrendezhetők** — a főoldal ezt a **kézi sorrendet** követi (azonos sorrendnél a legközelebbi időpont a döntő). Új program a lista végére kerül; átrendezéskor „Sorrend mentve ✓" villan.

---

## 7. Admin — Egyedi programok
Az időpont nélküli „ötlet"-kártyák kezelése (amikre a vendég ajánlatot kér). Két al-fül: **Aktuális** és **Archivált**.

### 7.1 Új egyedi program / szerkesztés
- **„+ Új egyedi program"** → **cím** + **rövid leírás** (a kártyán) + **részletes leírás** (a „Részletek" ablakban, rich-text) + **fotó** (a program-fotókkal közös, publikus tárolóba).
- Nincs időpont / ár / létszám — ez a lényegi különbség a Programoktól.

### 7.2 Sorrend, archiválás, törlés
- **Sorrend:** húzással (⠿), mint a Programoknál — a főoldal ezt követi.
- **Archiválás:** leveszi a főoldalról; a beérkezett ajánlatkérések megmaradnak.
- **Törlés:** végleges; a hozzá tartozó ajánlatkérések **NEM** törlődnek, csak elvesztik a kapcsolatot ezzel az ötlettel.

---

## 8. Admin — Ajánlatok
A beérkezett ajánlatkérések kezelése. **Státusz-fülek:** Ajánlatra vár · Kiküldve · Elfogadva · Elutasítva · Lemondva · Összes (számlálókkal), + **név-szűrő** és **📊 Excel-export** (a jelenlegi nézet).

### 8.1 A táblázat
Oszlopok: **azonosító** (`A-100`) · **program/ötlet** · **vendég** (név, telefon, e-mail, kiment levelek) · **fő** · **kívánt időpont** · **státusz** · **művelet**.

### 8.2 Az ajánlat életciklusa és a gombok
1. **Ajánlatra vár** — a friss kérés. Gombok: **Részletek · Ajánlat kiküldve · Elfogad · Elutasítás · Lemondás**.
   - **„Ajánlat kiküldve"** csak **jelzés**: azt rögzíti, hogy a rendszeren KÍVÜL, e-mailben adtál ajánlatot, és várod a választ. *(A rendszer itt nem küld levelet.)*
2. **Elfogad** → megnyílik az **elfogadás-űrlap** (lásd 8.3).
3. **Elutasítás / Lemondás** → megerősítés után beáll a státusz. Lemondani **elfogadás után is** lehet (vendég vagy szervező).
4. **Lezárt** (elutasítva/lemondva) soron **🗑 Törlés** is megjelenik (pucolás).

### 8.3 Elfogadás — a végleges adatok
Az **Elfogad** gomb űrlapot nyit, ahol **minden mező kötelező**:
- **Végleges időpont** · **végleges létszám** · **végleges ár** (ez **ÖSSZÁR** — a teljes rendezvényre, NEM fő/ár) · **ajánlat szövege** (lehet „Ajánlat a csatolmány szerint").
- **Csatolmány** (opcionális): pdf/docx/kép — egy **privát** tárolóba kerül, és a megerősítő levélhez mellékelhető.

Mentés után a státusz **„elfogadva"**, és az ajánlat bekerül a **naptárba** (a végleges időpontnál).

### 8.4 Részletek + belső jegyzet
A **„Részletek"** ablak mutatja a teljes kérést (kívánt időpont, üzenet…), és — elfogadott ajánlatnál — a végleges adatokat + a **csatolmány letöltését**. Van egy **belső jegyzet** mező is (privát — a vendég sosem látja). Elfogadottnál a **„Végleges adatok módosítása / megtekintése"** gombbal újranyitható az elfogadás-űrlap.

### 8.5 Levél a vendégnek — „✉ Levél"
Az **elfogadva / elutasítva / lemondva** soron a **„✉ Levél"** gomb a státusznak megfelelő sablonlevelet küldi — **Megerősítés** (a végleges adatokkal + a csatolmánnyal) / **Elutasítás** / **Lemondás** —, előnézettel, szerkeszthetően. A kiment levelek a **„✉ N kiment levél"** linknél nézhetők vissza.

---

## 9. Admin — Beállítások

### 9.1 Csapat e-mail cím
Kettős szerepe van:
1. **Ide érkeznek** a foglalás- és ajánlat-értesítők (a csapat értesítése új foglalásról / ajánlatkérésről).
2. Ez a **válaszcím (Reply-To)** a vendégeknek menő leveleken (ha a vendég válaszol, ide fut be).

> Ez **NEM a feladó** — a feladó a küldő szolgáltató (Resend) beállított címe. Részletek: `docs/email.md`.

### 9.2 Foglalási azonosító formátuma
Előtag (max 2 karakter) + kezdő sorszám (1–999), **élő előnézettel** (pl. `F-` + 100 → `F-100`). Mentés után a foglalások azonosítói eszerint jelennek meg.

### 9.3 Ajánlat-azonosító formátuma
Ugyanígy, de **külön** az ajánlatoknak (pl. `A-` + 100 → `A-100`), hogy ne keveredjen a foglalásokéval.

### 9.4 Foglalási info-sáv
A foglalási űrlapon megjelenő tájékoztató szöveg (pl. az előre utalásról).

### 9.5 E-mail sablonok — foglalási ÉS ajánlati (külön blokkban)
A sablonok **két, vizuálisan elkülönített csoportban** szerkeszthetők (tárgy + törzsszöveg, külön menthető): **Foglalási e-mail sablonok** és **Ajánlati e-mail sablonok**. Részletek a 10. fejezetben.

---

## 10. E-mail rendszer — hogyan működik

A rendszer a **Resend** szolgáltatáson át küld. Minden kiküldött levél naplózódik (a foglalásnál/ajánlatnál „✉ N kiment levél"). **Két, egymástól független küldő** van: a `send-email` (foglalás) és a `send-ajanlat-email` (ajánlat). A koncepció és a beállítás: `docs/email.md`, `install.html`.

### 10.1 A foglalási e-mail sablonok (7 db)
A **Beállítások → Foglalási e-mail sablonok** alatt szerkeszthető (tárgy + törzsszöveg, külön menthető):

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

### 10.2 A foglalási levelek négy küldési módja
1. **Automatikus, foglaláskor:** amikor a vendég foglal, magától kimegy a **Visszaigazolás** (neki) + a **Csapat-értesítő** (nektek). *(Beállítás: `install.html` — foglalás-webhook/trigger.)*
2. **Kézi, a Foglalások fülön:** a **„✉ Levél"** gomb a státusznak megfelelő levelet küldi (Jóváhagyás / Elutasítás / Lemondás), előnézettel, szerkeszthetően (4.6).
3. **Csoportos, időpont-elmaradáskor:** amikor egy időpontot „Elmarad"-ra állítasz, választhatod a *Program elmarad* levél kiküldését az érintett vendégeknek (6.4).
4. **Napi emlékeztető:** minden nap kimegy az **Emlékeztető** a **másnapi, jóváhagyott** foglalásoknak. *(Beállítás: `install.html` — pg_cron.)*

### 10.3 Ki a feladó, ki a címzett?
- **Feladó (From):** mindig a beállított küldő cím (a `MAIL_FROM`).
- **Vendég-levelek:** címzett = a vendég; válaszcím = a **Csapat e-mail cím** (a vendég válasza a csapathoz fut be).
- **Csapat-értesítő:** címzett = a **Csapat e-mail cím**; válaszcím = a vendég (a csapat egy „Válasz"-szal a vendégnek írhat).

### 10.4 Az ajánlati e-mailek (5 sablon, külön küldővel)
A **Beállítások → Ajánlati e-mail sablonok** alatt szerkeszthető (a foglalásiaktól elkülönítve). A `send-ajanlat-email` küldi őket, `{…}` behelyettesítéssel (`{nev} {azonosito} {program} {vegleges_idopont} {vegleges_letszam} {vegleges_ar} {ajanlat_szoveg}` stb.):

| Sablon | Mikor / kinek |
|---|---|
| **Visszaigazolás** | ajánlatkéréskor, a vendégnek (automatikus) |
| **Csapat-értesítő** | ajánlatkéréskor, a csapatnak (automatikus) |
| **Megerősítés** | elfogadáskor, a vendégnek (kézzel; a végleges adatokkal + opcionális csatolmánnyal) |
| **Elutasítás** | kézzel, a vendégnek |
| **Lemondás** | kézzel, a vendégnek |

> Az **ajánlat-egyeztetés maga a rendszeren KÍVÜL** zajlik (a szervező személyes e-mailben ad ajánlatot). Ezek a sablonok az állapot-jelzést és a végleges megerősítést szolgálják.

---

## 11. Közös / UX
- **Saját felugró ablakok** minden megerősítéshez/üzenethez (nincs böngésző-popup).
- **Túlfoglalás-védelem** mindenhol: a rendszer nem enged több foglalást, mint a max létszám; csoportos alkalomnál betartja a `max_foglalasok` és `min_letszam` korlátokat is (szerveroldalon, a triggerben).
- **Reszponzív**, sötét „parázs" dizájn; mobilon is használható.

---

## 12. Tervezett (még NEM működik)
- **Főoldali képek** admin-feltöltéssel (jelenleg fix képek a `web/kepek/` mappában).

*(Az Excel-/PDF-export és a keep-alive ping már működik.)*
