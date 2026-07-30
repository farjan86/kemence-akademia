// =====================================================================
//  Kemence Akadémia — e-mail küldő Edge Function (Deno / Supabase)
//
//  A leveleket a RESEND szolgáltatáson át küldi, és naplóz az email_log-ba.
//
//  Kétféle hívás (POST, JSON body):
//   1) NYERS teszt-mód:   { "to": "cim@pl.hu", "subject": "Teszt", "text": "Szia" }
//        → csak elküldi; nem olvas adatbázist, nem naplóz. A küldés tesztelésére.
//        (Resend teszt-módban a `to` a Resend-fiókod regisztrációs címe lehet.)
//   2) SABLON-mód:        { "booking_id": "<uuid>", "tipus": "jovahagyas" }
//        → beolvassa a foglalást + programot + settings + sablont, behelyettesíti
//          a {mezoket}, elküldi a megfelelő címzettnek, és ír az email_log-ba.
//
//  Titkok (Supabase → Edge Functions → Secrets):
//    RESEND_API_KEY   a Resend API-kulcsa (re_...)
//    MAIL_FROM        feladó, pl. 'Kemence Akadémia <onboarding@resend.dev>'
//                     (teszt-módban ez a fix cím; élesben a saját, igazolt domained címe)
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
      await kuld(body.to, body.subject, body.text ?? "");
      return valasz({ ok: true, mode: "raw", to: body.to });
    }

    // --- 2) SABLON-mód ---
    const { booking_id, tipus } = body;
    if (!booking_id || !tipus) {
      return valasz({ ok: false, error: "Adj meg { to, subject } vagy { booking_id, tipus } mezőket." }, 400);
    }

    const db = createClient(SUPABASE_URL, SERVICE_ROLE);

    const { data: b, error: be } = await db
      .from("bookings")
      .select("*, workshops ( cim, idopont )")
      .eq("id", booking_id)
      .single();
    if (be || !b) throw new Error("A foglalás nem található.");

    const { data: sablon } = await db
      .from("email_sablonok").select("targy, torzs").eq("tipus", tipus).single();
    if (!sablon) throw new Error("Nincs ilyen sablon: " + tipus);

    const { data: beall } = await db
      .from("settings").select("azonosito_elotag, azonosito_kezdo, levelezesi_email").eq("id", 1).single();

    const elotag = beall?.azonosito_elotag ?? "F-";
    const kezdo  = Number(beall?.azonosito_kezdo ?? 100);
    const azonosito = `${elotag}${Number(b.azonosito) + kezdo - 1}`;

    const mezok = {
      nev: b.nev, email: b.email, telefon: b.telefon,
      program: b.workshops?.cim ?? "",
      idopont: formatDatum(b.workshops?.idopont ?? null),
      letszam: b.letszam, azonosito,
    };

    const targy = behelyettesit(sablon.targy, mezok);
    const torzs = behelyettesit(sablon.torzs, mezok);

    // A CSAPAT-értesítő a csapat címére megy (Beállítások → „Csapat e-mail cím"),
    // minden más levél a foglaló (vendég) e-mail címére.
    const csapatCim = beall?.levelezesi_email ?? "";
    const cimzett = tipus === "csapat_ertesito" ? csapatCim : b.email;
    if (!cimzett) throw new Error("Nincs címzett. A csapat-értesítőhöz állítsd be a Csapat e-mail címet a Beállításokban.");

    // Reply-To: vendég-levélnél a csapat címe (oda jöjjön a válasz);
    // csapat-értesítőnél a vendég címe (a csapat közvetlenül tud válaszolni neki).
    const replyTo = tipus === "csapat_ertesito" ? b.email : (csapatCim || undefined);

    await kuld(cimzett, targy, torzs, replyTo);
    await db.from("email_log").insert({ booking_id, tipus, cimzett });

    return valasz({ ok: true, mode: "template", tipus, to: cimzett });
  } catch (e) {
    return valasz({ ok: false, error: String((e as Error)?.message ?? e) }, 500);
  }
});
