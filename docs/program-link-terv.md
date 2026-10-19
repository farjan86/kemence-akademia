# Megosztható program-link — funkcióterv

> Állapot: **IMPLEMENTÁLVA (2026-10-15)** — a kód elkészült; a `db/m_12-program-slug.sql`
> migráció a **fejlesztői** adatbázisban lefutott; a **demó** és az **éles** adatbázisban még hátra van.
> Készült: 2026-10-15. Ez a dokumentum az elfogadott tervet rögzíti.

---

## 1. Cél

Minden meghirdetett programnak legyen **saját, megosztható linkje**. Aki a linkre kattint, **csak azt az egy programot** látja, és onnan **azonnal foglalhat** is.

**Kitől indult az igény:** az **előadók** szeretnék megosztani a saját programjuk linkjét a saját felületeiken (Facebook, Messenger, Instagram). Az előadók **nem admin felhasználók** — nincs belépésük a rendszerbe. Ezért a másoló gomb a **publikus** kártyára kerül: az előadó maga megnyitja az oldalt, és egy kattintással viszi a linket, nem kell kérnie senkitől.

A linket **másolással osztják meg és kattintással nyitják meg** — senki nem gépeli be, és nem diktálja le. Ezért a hossza nem szempont.

**Nem cél (az ügyfél döntése alapján):**
- előadónkénti gyűjtőoldal (`?eloado=…`) **nem készül**;
- **az admin felületen semmi nem változik** — a link képzése teljesen automatikus.

---

## 2. A link formátuma

```
https://kemence-akademia.xyz/?program=kortars-napolyi-pizza-workshop
```

Lekérdező paraméteres forma, mert **nem igényel szerveroldali átírást** — a Hostingeren lévő statikus tárhelyen azonnal működik, `.htaccess`-módosítás nélkül.

### 2.1 Az azonosító (slug) képzése

A program **címéből**, mentéskor, automatikusan:

| Lépés | Példa |
|---|---|
| kiindulás | `Kortárs Nápolyi Pizza Workshop` |
| ékezetek átírása | `Kortars Napolyi Pizza Workshop` |
| kisbetűsítés | `kortars napolyi pizza workshop` |
| nem betű/szám → kötőjel | `kortars-napolyi-pizza-workshop` |
| többszörös/szélső kötőjel takarítása | `kortars-napolyi-pizza-workshop` |

- Magyar ékezetek: `á é í ó ö ő ú ü ű` → `a e i o o o u u u`.
- Hossz: legfeljebb **80 karakter** (a végén nem vágunk szó közepébe).
- **Egyediség kötelező.** Ütközésnél `-2`, `-3`, … toldalék.
- Ha a cím csupa olyan karakterből állna, amiből nem képezhető azonosító, a program **belső azonosítójának első 8 jegye** lesz a slug.

### 2.2 Átnevezéskor NEM változik

A slug a program **létrehozásakor** készül, és **cím átírásakor sem módosul magától**.

**Miért:** a megosztott link örökre él. Ha a slug követné a címet, minden korábban kitett megosztás néma halállal elromlana — erről sem az előadó, sem a csapat nem szerezne tudomást.

### 2.3 A slug teljesen automatikus — nincs admin-felület hozzá

A link képzése **kizárólag az adatbázisban** történik, a csapatnak nincs vele teendője: nem látja, nem állítja, nem tudja elrontani.

Ebből következik, hogy a link **hosszú lehet** (a hosszabb programcímekből 50–60 karakteres azonosító keletkezik). Ez tudatosan vállalt: a linket **nem diktálja be senki**, hanem másolással osztják meg és kattintással nyitják meg.

Ha egy link valaha mégis zavaróan hosszú lenne, a `slug` érték egyetlen SQL-paranccsal átírható — de ez kivételes eset, nem napi művelet.

---

## 3. Vendég-oldali viselkedés

### 3.1 Normál betöltés (link nélkül)

Változatlan: minden program megjelenik, ahogy most.

### 3.2 Program-link megnyitása

A `?program=…` paraméter esetén az oldal **program-nézetre** vált (módosítva 2026-10-15, az ügyfél kérésére):

- Csak a **fejléc**, a **Programok szakasz** és a **lábléc** marad; a nyitókép, az Élmény, a Rólunk, az Egyedi programok és a Webshop szakasz rejtve van. Így a látogató a fejléc alatt azonnal a programot látja, görgetés nélkül.
- A Programok szakasz **csak azt az egy kártyát** mutatja, ugyanazzal a tartalommal és **ugyanabban a méretben**, mint a teljes listában (fotó, állapot-sáv, előadók, leírás, időpont-csempék, foglalás).
- A kártya fölött egy sor jelzi a szűrést, alatta **„Összes programunk →"** hivatkozás, ami visszavisz a teljes oldalra és listára.
- A fejléc menüjének rejtett szakaszra mutató pontjai (Élmény, Webshop, Rólunk, Kérj ajánlatot) a **teljes oldalt** nyitják meg; a „Programok", a „Foglalj időpontot" és a „Kapcsolat" a lapon belül marad.
- Megvalósítás: a `body` `program-nezet` osztályt kap (`app.js`), a rejtést a CSS végzi — a kártyát ugyanaz a kód rajzolja, nincs második változat.
- A foglalás innen ugyanúgy indul, mint a teljes listáról — a foglalási ablak már ma is időpont-azonosítóval dolgozik, nem kell hozzányúlni.

### 3.3 Ha a link nem él

| Eset | Mit lát a látogató |
|---|---|
| **Archivált** program | „Ez a program jelenleg nem meghirdetett." + Összes programunk → |
| **Törölt** program | ugyanez |
| **Ismeretlen/elgépelt** azonosító | ugyanez |
| Nincs jövőbeli időpontja | a kártya **megjelenik**, a meglévő „Hamarosan" / „Új időpontok egyeztetés alatt" felirattal |

Semmilyen esetben nem üres oldal vagy hibaüzenet: a megosztott link mindig értelmes oldalra visz.

### 3.4 „Link másolása" gomb a publikus kártyán

- Minden program-kártyán, **fix helyen**, visszafogott megjelenéssel (nem versenyez a foglalás gombbal).
- Kattintásra a **teljes cím** a vágólapra kerül, és a gomb rövid visszajelzést ad (*„Link másolva"*).
- Ahol a vágólap nem érhető el (régi böngésző, nem biztonságos kapcsolat), tartalékként **kijelölhető mezőben** megmutatja a linket.
- Az **archivált** programok amúgy sem jelennek meg a publikus oldalon, így ott nincs is mit másolni.

---

## 4. Adatbázis

Új oszlop a `workshops` táblán:

| Oszlop | Típus | Megjegyzés |
|---|---|---|
| `slug` | `text` | egyedi index, `null` megengedett (a kitöltést trigger végzi) |

- **Trigger** (`before insert`): ha a `slug` üres, a címből képzi; ütközésnél toldalékol.
- **`update`-nél nem nyúl hozzá** — így az átnevezés nem rontja el a linket.
- A **publikus olvasás** a meglévő jogosultsági szabályok alá esik (a `programok` nézet bővül a `slug` oszloppal).
- **Egyszeri feltöltés** a meglévő programoknak.
- Fájl: `db/m_12-program-slug.sql`, és beolvad a `db/01-schema.sql`-be.

---

## 5. Ami NEM része ennek a fejlesztésnek

**Programonkénti közösségi előnézet (Open Graph).** A közösségi oldalak robotjai nem futtatnak JavaScriptet, ezért statikus tárhelyen minden program linkje alatt **ugyanaz az előnézet** jelenne meg.

Ebben a körben csak **oldal-szintű** megosztási adatot veszünk fel (cím, leírás, kép) — ma ugyanis **egyáltalán nincs**, így a közösségi oldalak találomra választanak címet és képet. Ez minden megosztáson javít, programonkénti előnézetet viszont nem ad.

A programonkénti előnézet később megléphető, de **tárhelyváltást igényelne** (Netlify / Cloudflare) — ez külön döntés, és a mostani munka akkor sem vész kárba.

---

## 6. Érintett fájlok

**Az admin felülethez nem nyúlunk** — ott semmi nem változik.

| Fájl | Mi történik |
|---|---|
| `db/m_12-program-slug.sql` | **új** — oszlop, index, trigger, feltöltés, nézet-frissítés |
| `db/01-schema.sql` | a fenti beolvasztása |
| `web/js/app.js` | link-olvasás, szűrt nézet, üres állapotok, másoló gomb bekötése |
| `web/index.html` | oldal-szintű megosztási adatok (`og:`) |
| `web/css/style.css` | a másoló gomb és a szűrt nézet sávjának stílusa |
| `felhasznaloi-utmutato` (HTML + DOCX) | új szakasz a megosztható linkről |
| `docs/funkcio-dokumentacio.md`, `docs/technikai-dokumentacio.md` | átvezetés |

---

## 7. Ellenőrzési lista

- [ ] Új program mentése → magától lesz linkje (admin-teendő nélkül)
- [ ] Két azonos című program → a második `-2` toldalékot kap
- [ ] Link megnyitása → csak a fejléc + az az egy kártya + lábléc; a menü rejtett pontjai a teljes oldalt nyitják
- [ ] Foglalás a megosztott linkről → végigmegy
- [ ] „Összes programunk →" → vissza a teljes listára
- [ ] Archivált / törölt / elgépelt link → értelmes üzenet, nem hiba
- [ ] Archivált program visszaállítása → a régi link **újra él**
- [ ] Cím átírása → a régi link **tovább él**
- [ ] Másoló gomb → vágólap + visszajelzés, mobilon is
- [ ] A meglévő programok mind kaptak linket
