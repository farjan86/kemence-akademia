# E-mail küldés — egyszerű magyarázat

> Ez a fájl **emberi nyelven** magyarázza el, hogyan küld a rendszer e-mailt, és miért.
> A technikai beállítás (kulcsok, parancsok) külön van: `docs/email-kuldes-setup.md`.

## A három szereplő
1. **Küldő motor** — a „posta", ami ténylegesen kézbesíti a leveleket. Ezt **nem mi üzemeltetjük**,
   hanem egy szolgáltatás. Kezdetben: **Resend**. (Később lehet a Google is — lásd lentebb.)
2. **Feladó cím** — ez a „feladó a borítékon", amit a vendég lát. A **te domained** egy címe.
3. **Fogadó postaláda** — ide jönnek a **válaszok** és a **csapat-értesítők**; ezt **ti olvassátok**
   (`akademia@mobilkemence.xyz`, Google Workspace).

> A lényeg: a fogadó postaláda (`akademia@mobilkemence.xyz`) az éles rendszerben **csak fogad**.
> A **küldést a küldő motor végzi** — abba a postaládába a rendszernek be sem kell lépnie.

## Mi az a Resend, és miért kell egyáltalán?
Ahhoz, hogy egy **program** levelet küldjön, kell egy levélküldő szerver, ami elfogadja és
kézbesíti a leveleket. Ezt nem érdemes magunknak üzemeltetni (a fogadók spamnek néznék).
Ezért egy kész szolgáltatást használunk. A **Resend** pontosan ez: kapsz tőle egy **kulcsot
(API key)**, azt beírjuk a Supabase-be, és a rendszer ezen keresztül küld. Ez a teljes szerepe.
*(Hasonló szolgáltatások: SendGrid, Brevo, Mailgun, Amazon SES. A Resend egy egyszerű, modern változat.)*

**Miért nem a Gmail rögtön?** Mert a Gmailen át küldéshez **postaláda + App Password + 2FA** kell,
és fejlesztés alatt nincs hozzáférésünk a domain postaládáihoz. A Resendhez **nem kell postaláda**.

**Mit csinál a Resend / mit NEM csinál:**
- ✅ **Küld** kimenő leveleket a domained nevében, kezeli a kézbesítést és a visszapattanásokat, ad statisztikát/naplót.
- ❌ **Nem fogad** leveleket — nincs mögötte postaláda, nem lehet benne „olvasni". Ezért irányítjuk a **válaszokat (Reply-To)** egy valódi, olvasott fiókra (`akademia@mobilkemence.xyz`).

Röviden: a Resend a **kimenő posta**, nem a postaládád.

## ⭐ Fejlesztés vs. éles — mi kell mikor?
| | **MOST (fejlesztés)** | **ÉLESBEN (ügyféllel)** |
|---|---|---|
| Küldő motor | Resend **teszt-mód** | Resend + a domain igazolva |
| Feladó cím | `onboarding@resend.dev` | amit az ügyfél akar (pl. `akademia@mobilkemence.xyz`) |
| Kell DNS-beállítás? | **NEM** | igen, pár rekord (lásd lentebb) |
| Kell domain/e-mail hozzáférés? | **NEM** | igen (az ügyfélé) |

➡️ **Fejlesztés alatt semmilyen domain- vagy e-mail-hozzáférés nem kell.** A Resend teszt-módja a
**saját (Resend-regisztrációs) címedre** küld — így az egész folyamatot végig tudod tesztelni.

## Mi az a DNS?
**DNS** = az internet „telefonkönyve": a domainhez (pl. `kemence-akademia.xyz`) tartozó beállítások
listája. Itt mondjuk meg többek közt, hová menjenek a levelek, és ki küldhet a domain nevében.

## Fogalmak egyszerűen: MX, SPF, DKIM
Képzeld a domainedet egy céges postázónak. Három dolgot állíthatunk a DNS-ben:

- **MX** (Mail eXchange) — **hová érkezzenek** a domainnek CÍMZETT levelek. Ez a **fogadásról** szól.
  Pl. a `mobilkemence.xyz` MX-e a Google → a beérkező levelek a Google-postaládába jönnek.
  *(Küldéskor NEM ezt használjuk.)*
- **SPF** (Sender Policy Framework) — **ki KÜLDHET** a domain nevében. Egy „engedélyezett feladók" lista.
  A fogadó (pl. Gmail) ezt nézi: ha a küldő szerver nincs a listán → gyanús/spam. **A küldés hitelesítése.**
  ⚠️ Egy névhez **csak EGY** SPF sor lehet — ha bővíteni kell, a meglévőt **kiegészítjük**, sosem teszünk mellé másodikat.
- **DKIM** (DomainKeys Identified Mail) — **digitális pecsét** a leveleken. A küldő aláírja a levelet egy
  titkos kulccsal, a fogadó a DNS-ben közzétett nyilvános kulccsal ellenőrzi → biztos, hogy tényleg a te
  domainedről jött és nem hamisított. **A hitelesség bizonyítéka.**

Analógia:
- **MX** = a postaláda címe (hová jön a levél).
- **SPF** = a portás listája (ki adhat fel a nevedben).
- **DKIM** = a viaszpecsét a borítékon (biztos, hogy tőled van).

## Mit kell a DNS-be tenni élesben? (Resend)
A Resendben: **Add Domain** → beírod a domaint → a Resend **kiírja a PONTOS rekordokat** (értékekkel együtt).
Ezeket bemásolod a **Hostinger DNS-be**, majd a Resendben **Verify**. Jellemzően **3 rekord** (a Resend a
saját `send.` aldomainjét használja):

| Típus | Hová (név) | Mit csinál |
|---|---|---|
| **MX** | `send.<domain>` | a visszapattanó (bounce) levelek kezelése |
| **TXT (SPF)** | `send.<domain>` | felhatalmazza a Resendet a küldésre |
| **TXT (DKIM)** | `resend._domainkey.<domain>` | a pecsét (aláírás-kulcs) |

> Mivel ezek egy **`send.` aldomainen** vannak, a fő-domain meglévő beállításait (pl. a Google MX-ét) **nem érintik**.
> **Hol csináljuk?** *Hostinger → a domain → DNS Zone / DNS-rekordok → új rekordok.* Ez **élesítéskor**, az ügyféllel.

## A feladó cím — két lehetőség élesre, és a hozzá tartozó DNS
**A) `noreply@kemence-akademia.xyz` — tiszta domain**
- A `kemence-akademia.xyz` **üres** (nincs MX/SPF). Csak a Resend 3 rekordját adod hozzá. **Nincs mit elrontani.**

**B) `akademia@mobilkemence.xyz` — a valódi cím (itt van Google-levelezés)**
- A **Google MX-ét NEM bántjuk** → a beérkező levelek maradnak a Google-postaládában.
- A Resend a `send.mobilkemence.xyz` aldomainre teszi az MX/SPF/DKIM-et → **nem ütközik** a fő-domain Google-rekordjaival.
- Ha valaha a **fő-domain SPF-jét** kellene bővíteni: a meglévő `v=spf1 include:_spf.google.com ~all`-t
  **egy sorban egészítjük ki**, sosem teszünk mellé második SPF-et.
- Ezért „óvatos" a B): a cél, hogy a **meglévő Google-levelezés sértetlen maradjon.** Ez az **ügyfél DNS-én, vele** történik.

## Később átállhatunk Google-re? — IGEN
A rendszer úgy épül, hogy a **küldés egyetlen helyen** van (a `send-email` függvény). Minden más
(sablonok, admin-gomb, foglalási folyamat, emlékeztető) csak annyit mond: „küldd el ezt a levelet" —
nem érdekli, HOGYAN megy.

Ezért ha az ügyfél később **Google-lel** (Workspace SMTP-vel, App Password-del) akar küldeni:
- **csak a `send-email` függvényt** írjuk át (Resend → Google SMTP), és **kicseréljük a secreteket**,
- a **sablonok, az admin-felület, az adatbázis, a logika VÁLTOZATLAN marad**,
- a feladó ilyenkor natívan `akademia@mobilkemence.xyz` lesz (mert abból a postaládából megy).

Vagyis a **Resend nem „örökre szóló" döntés** — bármikor átállítható Google-re (vagy más szolgáltatóra)
a rendszer többi részének érintése nélkül.

## Összefoglalva egy mondatban
> A leveleket egy **küldő szolgáltatás** (kezdetben Resend) küldi a **domained nevében**; a vendég a
> **domained egy címét** látja feladóként; a **válaszok és a csapat-értesítők** a **valódi Google-postaládátokba**
> (`akademia@mobilkemence.xyz`) futnak be, amit a megszokott felületen olvastok. A küldő szolgáltató
> **később bármikor lecserélhető** (pl. Google-re) a rendszer többi része nélkül.
