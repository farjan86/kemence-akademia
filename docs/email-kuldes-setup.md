# E-mail küldés beállítása (Resend + Edge Function)

> A `supabase/functions/send-email/index.ts` küldő függvényhez. Ez a lista végigvezet a
> Resend-fiók → API-kulcs → Supabase secret → deploy → teszt lépéseken.
> Emberi nyelvű magyarázat (mi ez, miért): `docs/email.md`.

## Hogyan küld a rendszer? (röviden)
A leveleket a **Resend** szolgáltatás küldi (egy „kimenő posta"). Kapsz tőle egy **API-kulcsot**,
azt beírod a Supabase-be, és a függvény ezen át küld. A Resend **csak küld, nem fogad** — ezért a
válaszokat (Reply-To) egy valódi postaládára irányítjuk (a Beállítások „Csapat e-mail cím"-ére).

- **Feladó (From):** a `MAIL_FROM` secret. Fejlesztésben `onboarding@resend.dev`, élesben a saját,
  Resendben **igazolt domained** címe (pl. `noreply@kemence-akademia.xyz` vagy `akademia@mobilkemence.xyz`).
- **Csapat-értesítő címzettje:** a Beállítások → „Csapat e-mail cím".

## 1. Resend-fiók + API-kulcs
1. Regisztrálj: **resend.com** (ingyenes; e-maillel/Google/GitHub).
2. **API Keys → Create API Key** → másold ki a kulcsot (`re_...`). Csak egyszer látszik!

> **Fejlesztői (teszt) korlát:** amíg **nincs igazolt domained**, a Resend csak
> `onboarding@resend.dev` feladóval és **CSAK a saját (regisztrációs) címedre** enged küldeni.
> Ez tökéletes a teszthez. Idegen címekre (valódi vendégek) küldeni majd a domain igazolása után lehet.

## 2. Titkok megadása a Supabase-ben
Supabase → a projekt → **Edge Functions → Secrets**:

| Név | Érték |
|---|---|
| `RESEND_API_KEY` | a Resend kulcs (`re_...`) |
| `MAIL_FROM` | fejlesztésben: `Kemence Akadémia <onboarding@resend.dev>` |

> A `SUPABASE_URL` és a `SUPABASE_SERVICE_ROLE_KEY` **automatikusan** elérhető — ezeket NEM kell megadni.

## 3. A függvény telepítése (deploy)
**Dashboard (nem kell CLI):** Supabase → **Edge Functions → Create a new function** → név: **`send-email`**
→ másold be a `supabase/functions/send-email/index.ts` teljes tartalmát → **Deploy**.

**Vagy CLI-vel:**
```bash
supabase login
supabase link --project-ref <PROJECT_REF>
supabase functions deploy send-email
```

## 4. Sablon-migráció (ha még nem futott)
`db/13-migracio-emlekezteto-sablon.sql` — az „emlékeztető" sablonhoz. (Üres telepítésnél a 01-ben már benne van.)

## 5. Teszt — NYERS mód
A `<PROJECT_REF>` és az `<ANON_KEY>` a Supabase → Project Settings → API alatt van.
A `to` **a Resend-fiókod regisztrációs címe** legyen (teszt-korlát miatt).

```bash
curl -i -X POST "https://<PROJECT_REF>.supabase.co/functions/v1/send-email" \
  -H "Authorization: Bearer <ANON_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"to":"A_RESEND_REGISZTRACIOS_CIMED@example.com","subject":"Teszt – Kemence Akadémia","text":"Ez egy teszt levél."}'
```
Sikeres válasz: `{"ok":true,"mode":"raw",...}` és a levél **megérkezik**.

## 6. Teszt — SABLON mód (valós foglalásra)
Válassz egy `booking_id`-t a `bookings` táblából, és egy sablon-`tipus`-t
(`visszaigazolas`, `jovahagyas`, `emlekezteto`, `csapat_ertesito`, …):

```bash
curl -i -X POST "https://<PROJECT_REF>.supabase.co/functions/v1/send-email" \
  -H "Authorization: Bearer <ANON_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"booking_id":"<UUID>","tipus":"visszaigazolas"}'
```
> Teszt-módban (domain nélkül) ez csak akkor kézbesül, ha a foglaló e-mailje = a Resend-regisztrációs címed.
> Egy sor bekerül az **`email_log`** táblába, és a `csapat_ertesito` a Beállítások „Csapat e-mail cím"-ére megy.

## 7. Éles üzem — domain igazolása
1. Resend → **Domains → Add Domain** → add meg a domaint (pl. `kemence-akademia.xyz`).
2. A Resend kiírja a **DNS-rekordokat** (MX + SPF + DKIM) — ezeket a **Hostinger DNS-be** másolod, majd **Verify**.
   Részletek és a fogalmak (MX/SPF/DKIM), plusz a `mobilkemence.xyz` „óvatos" esete: `docs/email.md`.
3. Állítsd át a `MAIL_FROM` secretet a saját címedre (pl. `Kemence Akadémia <noreply@kemence-akademia.xyz>`).
4. Kész — mostantól bárkinek mehet a levél a saját domained nevében.

## Hibaelhárítás
- **403 / „domain is not verified"** → teszt-módban vagy: csak `onboarding@resend.dev`-ről és csak a saját címedre. Igazold a domaint (7. lépés).
- **401 / „invalid API key"** → rossz vagy hiányzó `RESEND_API_KEY` secret.
- **A levél nem jött meg (teszt)** → a `to` nem a Resend-regisztrációs címed; vagy nézd a Resend → **Logs**-ot.
- **500-as függvényhiba** → Supabase → Edge Functions → `send-email` → **Logs**; a válasz `error` mezője is megmondja az okot.

## Következő lépések (a küldő működése után)
1. **Kézi „✉ Levél a partnernek" gomb** az adminban (a Foglalások soron) → `send-email` hívása `{booking_id, tipus}`-szal.
2. **Foglalás-webhook** (Database Webhook a `bookings` insertre) → automatikus visszaigazoló + csapat-értesítő.
3. **pg_cron** napi feladat → a másnapi **jóváhagyott** foglalásokhoz emlékeztető (pg_net hívja a függvényt).

## Váltás Google-re (később, ha az ügyfél úgy dönt)
Csak a `send-email` függvény `kuld()` részét kell átírni Google SMTP-re (App Password) és a secreteket
cserélni — a sablonok, az admin, az adatbázis és a logika változatlan. Lásd `docs/email.md`.
