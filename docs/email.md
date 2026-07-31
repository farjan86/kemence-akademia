# E-mail küldés — koncepció és beállítás (egyben)

> Ez a fájl mindent tartalmaz az e-mail-küldésről: **mi ez, miért így**, és a **beállítás lépésről lépésre**.
> A küldő függvény: `supabase/functions/send-email/index.ts`. Az éles telepítés checklistje: **`install.html`**.

---

## 1. A koncepció — a három szereplő

1. **Küldő motor** — a „posta", ami ténylegesen kézbesíti a leveleket. Nem mi üzemeltetjük, hanem egy szolgáltatás: a **Resend**.
2. **Feladó cím (From)** — a „feladó a borítékon", amit a vendég lát. A **saját, igazolt domained** egy címe.
3. **Fogadó postaláda** — ide jönnek a **válaszok** és a **csapat-értesítők**; ezt a csapat olvassa (`akademia@mobilkemence.xyz`, Google Workspace).

> **A lényeg:** a fogadó postaláda éles üzemben **csak fogad**. A küldést a **Resend** végzi — abba a postaládába a rendszernek be sem kell lépnie.

### Mi az a Resend, és miért kell?
Ahhoz, hogy egy program levelet küldjön, kell egy levélküldő szerver, ami elfogadja és kézbesíti a leveleket (magunknak nem érdemes üzemeltetni, a fogadók spamnek néznék). A **Resend** pontosan ez: kapsz tőle egy **API-kulcsot**, azt a Supabase-be tesszük, és a rendszer ezen át küld. *(Hasonlók: SendGrid, Brevo, Mailgun, Amazon SES.)*

- ✅ **Küld** a domained nevében, kezeli a visszapattanásokat, naplót ad.
- ❌ **Nem fogad** (nincs mögötte postaláda). Ezért a **válaszokat (Reply-To)** egy valódi fiókra irányítjuk.

---

## 2. Feladó, címzett, válaszcím — ki hova megy

| Levéltípus | Feladó (From) | Címzett | Válaszcím (Reply-To) |
|---|---|---|---|
| Vendég-levél (visszaigazolás, jóváhagyás, stb.) | a `MAIL_FROM` postaláda | a vendég | a **Csapat e-mail cím** |
| Csapat-értesítő (új foglalás) | a `MAIL_FROM` postaláda | a **Csapat e-mail cím** | a vendég |

- A **Feladó** mindig a `MAIL_FROM` secret (a bejelentkezett/igazolt cím). Tetszőleges cím nevében nem lehet küldeni.
- A **Csapat e-mail cím** az adminban állítható (Beállítások → Általános). Kettős szerepe van: a csapat-értesítők címzettje ÉS a vendég-levelek válaszcíme.
- A `noreply@…` helyett érdemes **barátságos feladót** (`akademia@…`) használni, mert a Reply-To miatt a vendég válaszolhat.

---

## 3. Fejlesztés vs. éles — mi kell mikor

| | **Fejlesztés** | **Éles (ügyféllel)** |
|---|---|---|
| Küldő | Resend + saját teszt-domain (`mislenyma.hu`) | Resend + a kliens igazolt domainje |
| Feladó | `…@mislenyma.hu` | `…@kemence-akademia.xyz` (vagy `akademia@mobilkemence.xyz`) |
| Fejlesztői védelem (`DEV_REDIRECT_TO`) | **BE** — minden levél egy tesztcímre | **KI** (törölni!) |

### 🔒 Fejlesztői védelem: `DEV_REDIRECT_TO`
Ha ez a secret be van állítva (pl. `janos.farkas86@gmail.com`), akkor **MINDEN levél KIZÁRÓLAG erre az egy címre** megy — a valós címzett a tárgyba kerül: `[TESZT → eredeti@cim] …`. Így fejlesztés közben valós/éles címre **fizikailag lehetetlen** küldeni. **⚠️ Élesben törölni kell.**

---

## 4. Beállítás lépésről lépésre

### 4.1 — Resend-fiók + API-kulcs
1. Regisztrálj: **resend.com** (ingyenes).
2. **API Keys → Create API Key** → másold ki a `re_…` kulcsot (csak egyszer látszik!), és tedd a gitignore-olt `secrets/titkok.txt`-be.

### 4.2 — Supabase secretek
Supabase → **Edge Functions → Secrets**:

| Név | Érték |
|---|---|
| `RESEND_API_KEY` | a Resend `re_…` kulcs |
| `MAIL_FROM` | a saját igazolt domained címe, pl. `Kemence Akadémia <akademia@mislenyma.hu>` |
| `DEV_REDIRECT_TO` *(fejlesztői védelem)* | pl. `janos.farkas86@gmail.com` — **⚠️ élesben töröld!** |

> A `SUPABASE_URL` és `SUPABASE_SERVICE_ROLE_KEY` **automatikusan** elérhető — ezeket NEM kell megadni.

### 4.3 — A `send-email` függvény deploy
> ⚠️ Az **Edge Functions** menü kell (TypeScript), **NEM** a Database → Functions (SQL). Az Edge Functions-nél csak **név + kód-szerkesztő + Deploy** van.

Supabase → **Edge Functions → Deploy a new function** → név **`send-email`** → beilleszted a `supabase/functions/send-email/index.ts` teljes tartalmát → **Deploy**. *(CLI-vel: `supabase functions deploy send-email`.)*

---

## 5. Teszt

**Nyers mód** (csak az SMTP/kapcsolat teszteléséhez, PowerShell):
```powershell
Invoke-RestMethod -Method Post -Uri "https://<PROJECT_REF>.supabase.co/functions/v1/send-email" `
  -Headers @{ Authorization = "Bearer <ANON_KEY>" } -ContentType "application/json" `
  -Body '{"to":"<A_CIMED>","subject":"Teszt","text":"Szia"}'
```

**Sablon mód** (valós foglalásra): a `<PROJECT_REF>` és `<ANON_KEY>` a Supabase → Project Settings → API alatt.
```
{"booking_id":"<UUID>","tipus":"visszaigazolas"}
```
A `csapat_ertesito` a Csapat e-mail címre megy, minden más a vendégnek. Minden küldés bekerül az `email_log` táblába.

> A `DEV_REDIRECT_TO` miatt fejlesztésben minden a tesztcímedre jön (`[TESZT → …]` tárggyal).

---

## 6. Éles domain igazolása (DNS)

### Fogalmak egyszerűen
- **MX** (Mail eXchange) — **hová érkezzenek** a domainnek CÍMZETT levelek (fogadás). *(Küldéskor nem ezt használjuk.)*
- **SPF** (Sender Policy Framework) — **ki KÜLDHET** a domain nevében (engedélyezett feladók listája). ⚠️ Egy névhez **csak egy** SPF-sor lehet.
- **DKIM** (DomainKeys Identified Mail) — **digitális pecsét/aláírás**, ami bizonyítja, hogy a levél valóban a domainedről jött.

Analógia: **MX** = a postaláda címe · **SPF** = a portás listája · **DKIM** = a viaszpecsét a borítékon.

### A menet
1. Resend → **Domains → Add Domain** → a küldő domain.
2. A Resend kiír **3 rekordot** (a `send.` aldomainen): **MX**, **TXT (SPF)**, **TXT (DKIM)** → bemásolod a domain DNS-ébe (Hostinger/Rackhost) → **Verify**.
3. `MAIL_FROM` átállítása a saját domain címére.

> Mivel a rekordok a `send.` aldomainen vannak, a fő-domain meglévő beállításait (pl. a Google MX-ét) **nem érintik**. Ha valaha a fő-domain SPF-jét kell bővíteni: a meglévőt **egészítsd ki egy sorban**, ne tegyél mellé másodikat.

**Feladó-opciók élesre:** A) `noreply@kemence-akademia.xyz` (tiszta domain, kockázatmentes) · B) `akademia@mobilkemence.xyz` (valódi cím, a Google-levelezés mellé — óvatos DNS).

---

## 7. Limitek (Resend ingyenes csomag)
- **3 000 levél / hó**, **100 levél / nap**, **1 igazolt domain**, 30 napos napló-megőrzés.
- Ehhez a projekthez **bőven elég**. A saját `email_log` táblánk korlátlanul megőrzi a küldéseket.
- (Pro: $20/hó, 50 000 levél — valószínűleg sosem kell.)

---

## 8. Később Google-re váltás? — IGEN
A küldés **egyetlen helyen** van (a `send-email` függvény `kuld()` része). Ha a kliens Google-lel (Workspace SMTP + App Password) akar küldeni: csak a függvény `kuld()` részét írjuk át és a secreteket cseréljük — a **sablonok, admin, adatbázis, logika változatlan**. A Resend tehát nem végleges döntés.

---

## 9. Hibaelhárítás
- **„domain is not verified" (403)** → a `MAIL_FROM` nem igazolt domainen van, VAGY (teszt-módban) idegen címre próbálsz küldeni. Igazold a domaint (6. pont). Figyelem: nem igazolt domainen lévő **Reply-To** is kiválthatja!
- **„invalid API key" (401)** → rossz/hiányzó `RESEND_API_KEY` secret.
- **A levél nem jön meg** → nézd a Resend → **Logs**-ot és a Supabase → Edge Functions → `send-email` → **Logs**-ot; a válasz `error` mezője megmondja az okot.

---

## Kapcsolódó
- Élesítési checklist (secretek, deploy, webhook, cron, DNS): **`install.html`**.
- E-mail sablonok szerkesztése: admin → Beállítások → E-mail sablonok.
- Automatika (auto visszaigazoló + napi emlékeztető): `db/03-auto-visszaigazolo-trigger.sql`, `db/04-emlekezteto-cron.sql`.
