// =====================================================================
//  Kemence Akadémia — e-mail küldő Edge Function (Deno / Supabase)
//
//  A leveleket a RESEND szolgáltatáson át küldi, és naplóz az email_log-ba.
//
//  HÁROMFÉLE hívás (POST, JSON body):
//   1) NYERS teszt-mód:   { "to": "cim@pl.hu", "subject": "Teszt", "text": "Szia" }
//        → csak elküldi; nem olvas adatbázist, nem naplóz. A küldés tesztelésére.
//   2) WEBHOOK-mód (Supabase Database Webhook a bookings INSERT-re):
//        { "type":"INSERT", "table":"bookings", "record": { ... új foglalás ... } }
//        → új, „jóváhagyásra vár" foglalásnál AUTO kiküldi a visszaigazolót (vendég)
//          + a csapat-értesítőt (csapat cím).
//   3) SABLON-mód (kézi / adminból): { "booking_id":"<uuid>", "tipus":"jovahagyas" }
//        (opcionálisan { "targy":"...", "torzs":"..." } — az adminban szerkesztett szöveg)
//        → beolvassa a foglalást + programot + sablont, behelyettesíti, elküldi, naplóz.
//
//  Titkok (Supabase → Edge Functions → Secrets):
//    RESEND_API_KEY   a Resend API-kulcsa (re_...)
//    MAIL_FROM        feladó, pl. 'Kemence Akadémia <akademia@mislenyma.hu>'
//    DEV_REDIRECT_TO  (opcionális) fejlesztői védelem — MINDEN levél csak erre a címre.
//  A SUPABASE_URL és a SUPABASE_SERVICE_ROLE_KEY automatikusan elérhető.
// =====================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const MAIL_FROM      = Deno.env.get("MAIL_FROM") ?? "Kemence Akadémia <onboarding@resend.dev>";
const SUPABASE_URL   = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE   = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

// FEJLESZTŐI VÉDELEM ("catch-all"): ha ez a secret be van állítva, MINDEN levél KIZÁRÓLAG
// erre az egy címre megy (a valós címzettet a tárgy elejébe tesszük: [TESZT → ...]).
// Így fejlesztés közben valós/éles címre SOHA nem megy semmi. Élesben töröld / hagyd üresen.
const DEV_REDIRECT_TO = Deno.env.get("DEV_REDIRECT_TO") ?? "";

// {mezo} behelyettesítése a sablon szövegébe
function behelyettesit(sablon: string, mezok: Record<string, unknown>): string {
  return String(sablon).replace(/\{(\w+)\}/g, (_, k) => String(mezok[k] ?? ""));
}

function formatDatum(iso: string | null): string {
  if (!iso) return "";
  return new Date(iso).toLocaleString("hu-HU", { dateStyle: "long", timeStyle: "short" });
}

// Egyetlen levél elküldése a Resend API-n át.
// A feladó (from) a MAIL_FROM; a válaszcím (reply_to) szabadon állítható.
async function kuld(to: string, subject: string, text: string, replyTo?: string): Promise<void> {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: MAIL_FROM,
      to: [to],
      subject,
      text,
      ...(replyTo ? { reply_to: replyTo } : {}),
    }),
  });
  if (!res.ok) {
    const reszletek = await res.text();
    throw new Error(`Resend hiba (${res.status}): ${reszletek}`);
  }
}

// Egy foglaláshoz tartozó sablon-levél kiküldése + naplózás.
// Ha targyIn/torzsIn adott, azt küldi (adminban szerkesztett szöveg); különben a sablonból.
// Visszaadja a tényleges címzettet.
async function kuldSablon(
  db: ReturnType<typeof createClient>,
  booking_id: string,
  tipus: string,
  targyIn?: unknown,
  torzsIn?: unknown,
): Promise<string> {
  const { data: b, error: be } = await db
    .from("bookings")
    .select("*, workshops ( cim, idopont )")
    .eq("id", booking_id)
    .single();
  if (be || !b) throw new Error("A foglalás nem található: " + booking_id);

  const { data: beall } = await db
    .from("settings").select("azonosito_elotag, azonosito_kezdo, levelezesi_email").eq("id", 1).single();

  let targy: string, torzs: string;
  if (typeof targyIn === "string" && typeof torzsIn === "string") {
    targy = targyIn;
    torzs = torzsIn;
  } else {
    const { data: sablon } = await db
      .from("email_sablonok").select("targy, torzs").eq("tipus", tipus).single();
    if (!sablon) throw new Error("Nincs ilyen sablon: " + tipus);

    const elotag = beall?.azonosito_elotag ?? "F-";
    const kezdo  = Number(beall?.azonosito_kezdo ?? 100);
    const azonosito = `${elotag}${Number(b.azonosito) + kezdo - 1}`;
    const mezok = {
      nev: b.nev, email: b.email, telefon: b.telefon,
      program: b.workshops?.cim ?? "",
      idopont: formatDatum(b.workshops?.idopont ?? null),
      letszam: b.letszam, azonosito,
    };
    targy = behelyettesit(sablon.targy, mezok);
    torzs = behelyettesit(sablon.torzs, mezok);
  }

  // A CSAPAT-értesítő a csapat címére megy (Beállítások → „Csapat e-mail cím"),
  // minden más levél a foglaló (vendég) e-mail címére.
  const csapatCim = beall?.levelezesi_email ?? "";
  const cimzett = tipus === "csapat_ertesito" ? csapatCim : b.email;
  if (!cimzett) throw new Error("Nincs címzett (a csapat-értesítőhöz állítsd be a Csapat e-mail címet).");

  // Reply-To: vendég-levélnél a csapat címe; csapat-értesítőnél a vendég címe.
  let replyTo = tipus === "csapat_ertesito" ? b.email : (csapatCim || undefined);

  // Fejlesztői védelem: minden levél a DEV_REDIRECT_TO címre, a valós címzett a tárgyban.
  let vegTargy = targy, vegCimzett = cimzett;
  if (DEV_REDIRECT_TO) {
    vegTargy = `[TESZT → ${cimzett}] ${targy}`;
    vegCimzett = DEV_REDIRECT_TO;
    replyTo = DEV_REDIRECT_TO;
  }

  await kuld(vegCimzett, vegTargy, torzs, replyTo);
  await db.from("email_log").insert({ booking_id, tipus, cimzett });   // a naplóban a valós (szándékolt) címzett
  return vegCimzett;
}

function valasz(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return valasz({ ok: false, error: "Csak POST." }, 405);

  try {
    if (!RESEND_API_KEY) throw new Error("Hiányzik a RESEND_API_KEY secret.");
    const body = await req.json().catch(() => ({}));

    // --- 1) NYERS teszt-mód ---
    if (body.to && body.subject) {
      let to = body.to, subject = body.subject;
      if (DEV_REDIRECT_TO) { subject = `[TESZT → ${to}] ${subject}`; to = DEV_REDIRECT_TO; }
      await kuld(to, subject, body.text ?? "");
      return valasz({ ok: true, mode: "raw", to });
    }

    const db = createClient(SUPABASE_URL, SERVICE_ROLE);

    // --- 2) WEBHOOK-mód: új foglalás → auto visszaigazoló + csapat-értesítő ---
    if (body.type === "INSERT" && body.record && body.record.id) {
      const rec = body.record;
      // Csak új, publikus foglalásnál (jóváhagyásra vár); egyébként nem csinálunk semmit.
      if (rec.statusz && rec.statusz !== "jovahagyasra_var") {
        return valasz({ ok: true, mode: "webhook", skipped: "nem jovahagyasra_var" });
      }
      const eredmeny: Record<string, unknown> = { ok: true, mode: "webhook", booking_id: rec.id };
      try { eredmeny.visszaigazolas = await kuldSablon(db, rec.id, "visszaigazolas"); }
      catch (e) { eredmeny.visszaigazolas_hiba = String((e as Error)?.message ?? e); }
      try { eredmeny.csapat_ertesito = await kuldSablon(db, rec.id, "csapat_ertesito"); }
      catch (e) { eredmeny.csapat_ertesito_hiba = String((e as Error)?.message ?? e); }
      return valasz(eredmeny);
    }

    // --- 3) SABLON-mód (kézi / adminból): { booking_id, tipus, (targy, torzs) } ---
    const { booking_id, tipus, targy: targyIn, torzs: torzsIn } = body;
    if (!booking_id || !tipus) {
      return valasz({ ok: false, error: "Adj meg { to, subject } vagy { booking_id, tipus } (vagy webhook payload) mezőket." }, 400);
    }
    const to = await kuldSablon(db, booking_id, tipus, targyIn, torzsIn);
    return valasz({ ok: true, mode: (typeof targyIn === "string" ? "custom" : "template"), tipus, to });
  } catch (e) {
    return valasz({ ok: false, error: String((e as Error)?.message ?? e) }, 500);
  }
});
