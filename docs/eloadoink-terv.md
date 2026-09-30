# Előadóink — funkcióterv

> Állapot: **IMPLEMENTÁLVA (2026-09-30)** — a funkció elkészült, a `m_11-eloadok.sql` migráció lefuttatása van hátra
> a fejlesztői és a demó adatbázisban. Ez a dokumentum az elfogadott tervet rögzíti.
> Készült: 2026-09-30. Az ügyfél minden nyitott kérdésben döntött (2026-09-30), **a terv kész a megvalósításra**.

---

## 1. Cél

A főoldal **Rólunk** szakaszában, a szöveg alatt jelenjen meg a **csapattagok kattintható névsora**. Egy névre kattintva felugrik az adott kolléga **bemutatkozása fényképpel**.

A tartalmat az ügyfél maga kezeli az adminban, egy új **Előadóink** fülön: felvitel, módosítás, elrejtés, törlés.

Emellett a **programoknál lévő „Előadó" mező is ehhez a listához kapcsolódik**: a programhoz a felvett előadók közül lehet választani, és a program kártyáján az ő nevük jelenik meg.

---

## 2. Vendég-oldali viselkedés

### 2.1 A Rólunk szakaszban

A `#rolunk` szakaszban, a bal oldali szövegdoboz (`.about-text`) **alatt**, az „about-stats" sáv után. A jobb oldali csapatkép (`.about-photo`) változatlan.

- Rövid felvezető sor (pl. „Ők tanítanak:"), alatta a **nevek egymás mellett**, sortöréssel.
- Minden név **kattintható**, vizuálisan is jelezve.
- Kattintásra **felugró ablak**: fénykép (ha van), név, bemutatkozó szöveg. Bezárás ×-szel, háttérre kattintva, Esc-cel.
- A nevek az adminban beállított **kézi sorrendben**.
- **Rejtett** előadó itt nem jelenik meg.
- **Üres állapot:** ha nincs látható előadó, a blokk (a felvezető sorral együtt) **meg sem jelenik** — a szakasz olyan, mint ma.

### 2.2 A program-kártyákon

A programkártyán ma ez áll: „Előadó: Szabó Zoltán" (szabad szövegből). Ezután:

- a név **a kapcsolt előadóból** jön, tehát mindig naprakész (ha az adminban átírják a nevet, itt is változik);
- a név **kattintható**, és ugyanazt a bemutatkozó ablakot nyitja meg, mint a Rólunk szakaszban;
- **több előadó** esetén vesszővel elválasztva, mindegyik külön kattintható;
- ha az előadó **rejtett**, a neve továbbra is megjelenik a kártyán — tény, hogy ő tartja a workshopot —, de **nem kattintható**, bemutatkozás nélkül.

---

## 3. Admin-oldali viselkedés

### 3.1 Az új fül helye

A fülsorban az **Egyedi megrendelések csoport után, a Rendszer csoport előtt**, saját csoportként:

```
NYILVÁNOS PROGRAMOK   │ EGYEDI MEGRENDELÉSEK        │ CSAPAT      │ RENDSZER
Foglalások Programok  │ Ajánlatok Egyedi programok  │ Előadóink   │ ⚙ Beállítások      👥 Partnerek  📅 Naptár
```

A csoport felirata: **„Csapat"**.

### 3.2 A lista — csupasz forma

Soronként **csak a legszükségesebb**, kép és szövegrészlet nélkül:

```
⠿   Szabó Zoltán                            [Rejtett]   Szerkesztés · Rejtés · Törlés
```

- **⠿** — fogantyú a sorrend húzásához
- **Név**
- **[Rejtett]** jelzés, ha nem látszik a főoldalon
- **[N program]** jelzés, ha programhoz van kötve (ez magyarázza, miért nincs Törlés gomb)
- gombok: **Szerkesztés · Rejtés/Megjelenítés · Törlés**

Fent: **+ Új előadó** gomb. A rejtettek ugyanebben a listában maradnak, jelzéssel — nincs külön alfül (kevés elemről van szó).

### 3.3 Szerkesztő ablak

Felugró ablak, mezők:

- **Név** — kötelező, max. 100 karakter
- **Bemutatkozás** — formázható szöveg (a program-leírásnál használt szerkesztővel)
- **Fénykép** — feltöltés előnézettel, cserélhető; **nem kötelező**

### 3.4 Műveletek és szabályok

| Művelet | Szabály |
|---|---|
| **Új előadó** | a lista végére kerül |
| **Szerkesztés** | minden mező módosítható, a kép cserélhető |
| **Rejtés / Megjelenítés** | **bármikor**, akkor is, ha programhoz van kötve |
| **Törlés** | **csak akkor, ha egyetlen programhoz sincs kötve.** Ha van kapcsolat, a Törlés gomb meg sem jelenik — helyette a sorban ott a `[N program]` jelzés. Ugyanaz a logika, mint a programoknál és az egyedi programoknál. |
| **Sorrend** | húzással, azonnali mentéssel |

### 3.5 A program-szerkesztőben

A mai szabad szöveges „Előadó" mező helyére **pipálható lista** kerül: a felvett előadók neve egymás alatt, mindegyik előtt jelölőnégyzet. Aki be van pipálva, az tartja a programot — **több is lehet** (a jelenlegi adatban is van kétszereplős program).

Miért ez a forma: nem kell hozzá külön könyvtár, telefonon is kezelhető, és egy pillantásra látszik, ki van kiválasztva. Kevés név (3–30) esetén ez a legkényelmesebb.

A **rejtett** előadók is választhatók — a rejtés csak a bemutatkozás megjelenítését érinti.

A kártyán a nevek az **Előadóink listában beállított sorrendben** jelennek meg; programonként külön sorrend nincs. (Ha később mégis kellene, a címkés választó irányába lehet továbblépni.)

---

## 4. Adatmodell

### 4.1 Új tábla: `public.eloadok`

```sql
create table if not exists public.eloadok (
  id             uuid primary key default gen_random_uuid(),
  nev            text not null check (char_length(nev) <= 100),
  bemutatkozas   text,
  foto_url       text,                              -- a PUBLIKUS program-fotok bucketben
  sorrend        integer not null default 0,        -- kézi sorrend (admin húzással)
  rejtett        boolean not null default false,    -- true = nem látszik a Rólunk névsorban
  created_at     timestamptz not null default now()
);
create index if not exists eloadok_rejtett_idx on public.eloadok (rejtett);
create index if not exists eloadok_sorrend_idx on public.eloadok (sorrend);
```

### 4.2 Kapcsolótábla: `public.program_eloadok`

Egy programhoz több előadó tartozhat, és egy előadó több programon is szerepelhet:

```sql
create table if not exists public.program_eloadok (
  workshop_id uuid not null references public.workshops(id) on delete cascade,
  eloado_id   uuid not null references public.eloadok(id)   on delete restrict,
  primary key (workshop_id, eloado_id)
);
create index if not exists program_eloadok_eloado_idx on public.program_eloadok (eloado_id);
```

A táblában **nincs sorrend-mező**: a kártyán a nevek az `eloadok.sorrend` szerint jelennek meg (lásd 3.5).

Két fontos részlet:

- **`on delete cascade` a program felől**: ha egy programot törölnek, a hozzárendelés is megszűnik — az előadó megmarad.
- **`on delete restrict` az előadó felől**: az adatbázis **megtiltja** a programhoz kötött előadó törlését. Így a szabály nemcsak a felületen él, hanem kerülőúton sem sérthető meg.

### 4.3 Jogosultság (RLS)

Mindkét tábla a publikus tartalom mintáját követi (bárki olvashatja, csak bejelentkezett admin írhatja):

```sql
alter table public.eloadok enable row level security;
drop policy if exists eloadok_read on public.eloadok;
create policy eloadok_read on public.eloadok for select using (true);
drop policy if exists eloadok_admin on public.eloadok;
create policy eloadok_admin on public.eloadok for all to authenticated
  using (auth.uid() is not null) with check (auth.uid() is not null);

alter table public.program_eloadok enable row level security;
drop policy if exists program_eloadok_read on public.program_eloadok;
create policy program_eloadok_read on public.program_eloadok for select using (true);
drop policy if exists program_eloadok_admin on public.program_eloadok;
create policy program_eloadok_admin on public.program_eloadok for all to authenticated
  using (auth.uid() is not null) with check (auth.uid() is not null);
```

### 4.4 A `programok` nézet

A publikus oldal a `programok` nézetből dolgozik. A nézet egészüljön ki az előadók listájával (id + név + rejtett jelző), hogy a kártya egy lekérdezésből megkapja a kattintható neveket.

### 4.5 A régi `workshops.eloado` mező — TÖRÖLVE

A szabad szöveges mező **megszűnt** (2026-09-30). Eredetileg biztonsági hálónak hagytuk volna meg, de a gyakorlatban ellentmondáshoz vezetett: ha a programnál nem volt bepipálva senki, a kártya „visszahozta" a régi, elavult nevet — akkor is, ha az admin szándékosan üresre állította.

Ezért:

- a `m_11` migráció **eldobja az oszlopot** (`alter table public.workshops drop column if exists eloado`);
- a `programok` nézet és a felületi kód már nem hivatkozik rá;
- ha egy programhoz nincs előadó, a kártyán **nincs „Előadó:" sor** — nincs visszaesés.

A régi szövegek ezzel elvesznek; ez vállalható, mert éles rendszer még nincs, a fejlesztői és a demó adat pedig újra felvehető.

### 4.6 Kép tárolása

A meglévő **`program-fotok`** bucket (publikus), `eloado-` előtagú fájlnévvel. Nem kell új bucket, a meglévő feltöltő kód változatlanul használható.

---

## 5. A meglévő adat

**Döntés (2026-09-30): a régi neveket NEM vesszük át automatikusan.** A migráció csak létrehozza a táblákat, és eldobja a régi szöveges oszlopot.

Az indok: a korábbi szövegek elírásokat és rövidítéseket tartalmaztak („Farkas jános", „Andi"), bemutatkozás és kép pedig egyikhez sem tartozott. Tisztább néhány nevet kézzel, rendesen felvinni az **Előadóink** fülön, mint hibás adatot örökölni.

Teendő a migráció után: az adminban felvenni az előadókat (név, bemutatkozás, kép), majd a programoknál bepipálni őket.

---

## 6. Érintett fájlok

### Adatbázis

| Fájl | Teendő |
|---|---|
| `db/01-schema.sql` | `eloadok` + `program_eloadok` tábla, indexek, RLS, és a `programok` nézet kiegészítése |
| `db/m_11-eloadok.sql` | **új migráció** a fejlesztői és a demó adatbázishoz: táblák, RLS, nézet, és a meglévő nevek átvétele (5. szakasz). Újrafuttatható. |

### Publikus oldal

| Fájl | Teendő |
|---|---|
| `web/index.html` | névsor a `#rolunk` szakaszban + új bemutatkozó ablak (`#eloadoModal`) |
| `web/js/eloadok.js` (új) | előadók betöltése, névsor kirajzolása, ablak kezelése |
| `web/js/app.js` | a program-kártyán az előadók neve kattinthatóan, a nézet új mezőjéből |
| `web/css/style.css` | névsor és ablak stílusa |

### Admin

| Fájl | Teendő |
|---|---|
| `web/admin/index.html` | „Csapat" fülcsoport + Előadóink panel + szerkesztő ablak; a program-szerkesztőben előadó-választó |
| `web/admin/js/eloadok.js` (új) | lista, felvitel, szerkesztés, rejtés, törlés, sorrend, képfeltöltés |
| `web/admin/js/programok.js` | az „Előadó" szöveges mező helyett választó; mentéskor a kapcsolatok szinkronizálása |
| `web/admin/js/core.js` | betöltés a fülre lépéskor (egy sor) |
| `web/admin/admin.css` | a csupasz lista stílusa |

### Dokumentáció

| Fájl | Teendő |
|---|---|
| `build_docx.py` | új szakasz a kézikönyvbe (előadók kezelése) + a programfelvitelnél az előadó-választás említése |
| `install.html` | az 1.2 felsorolásban a két új tábla |

---

## 7. Eldöntött kérdések

| Kérdés | Döntés (2026-09-30) |
|---|---|
| Az admin lista formája | **Csupasz lista** — kép és szövegrészlet nélkül (3.2) |
| A fül helye | Saját **„Csapat"** csoport, az Egyedi megrendelések után, a Rendszer előtt (3.1) |
| Előadó választása a programnál | **Pipálható lista**, több előadó is jelölhető (3.5) |
| Programonkénti névsorrend | Nincs — az Előadóink lista sorrendje dönt (4.2) |
| Törlés | Csak programhoz **nem kötött** előadó törölhető; az adatbázis is tiltja (3.4, 4.2) |
| Rejtés | **Bármikor**, akkor is, ha programon szerepel (3.4) |
| Rejtett előadó a program-kártyán | A neve **látszik**, de **nem kattintható** (2.2) |
| A meglévő nevek átvétele | **Automatikus** a migrációban; a régi szöveges mező biztonsági hálóként megmarad (4.5, 5.) |
| Bemutatkozás formázása | **Formázható**, a meglévő szerkesztővel (3.3) |
| Fénykép | **Nem kötelező** (3.3) |

**Egy dolog, amit érdemes szem előtt tartani:** a csupasz lista 3–30 fő között kényelmes. Ha az előadók száma ezt meghaladná, a lista fölé kereső kellhet — ez külön, apró feladat lenne.

---

## 8. Ami NEM része ennek a feladatnak

- Előadónkénti aloldal vagy saját URL (a bemutatkozás felugró ablakban jelenik meg).
- Elérhetőség, közösségi linkek, önéletrajz-melléklet.
- Előadó hozzárendelése **egyedi programhoz** (csak a listás programokhoz).
- Több nyelv.

---

## 9. Elfogadási kritériumok

1. Az adminban felvett előadó megjelenik a Rólunk szakaszban, a beállított sorrendben.
2. A névre kattintva felugrik a bemutatkozás a képpel; ×, háttér és Esc zárja.
3. A **rejtett** előadó nem jelenik meg a Rólunk névsorban, de az adminban igen.
4. Ha nincs látható előadó, a Rólunk szakasz a mai állapotával egyezik.
5. A program-szerkesztőben a pipálható listából **több előadó** is kijelölhető; mentés után a kártyán vesszővel elválasztva, az Előadóink lista sorrendjében jelennek meg.
6. A program-kártyán a név **kattintható**, és ugyanazt az ablakot nyitja.
7. **Programhoz kötött előadó nem törölhető** — a gomb meg sem jelenik, és az adatbázis is tiltja.
8. Az előadó **bármikor elrejthető**, akkor is, ha programon szerepel.
9. A **sorrend húzással** átrendezhető, és újratöltés után is megmarad.
10. A migráció után minden meglévő program előadója a helyén van (átvett névvel vagy a régi szöveggel).

---

## 10. Becsült méret

| Rész | Nagyságrend |
|---|---|
| Adatbázis (két tábla, nézet, migráció a névátvétellel) | közepes |
| Admin: Előadóink fül (csupasz lista, szerkesztő, kép, sorrend) | közepes |
| Admin: program-szerkesztő átállítása pipálható listára | kicsi |
| Publikus névsor + ablak + kártya-nevek | kicsi |
| Dokumentáció | kicsi |

A legtöbb figyelmet a **program-előadó kapcsolat** és a **meglévő nevek átvétele** igényli — a többi a meglévő minták újrahasznosítása.

---

## 11. Teendők a megvalósítás után

1. Migráció lefuttatása a **fejlesztői**, majd a **demó** Supabase projektben.
2. Az átvett nevek rendbetétele az adminban (elírások, teljes nevek), bemutatkozások és képek feltöltése.
3. Kézikönyv frissítése, `install.html` kiegészítése.
