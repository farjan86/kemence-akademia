// =====================================================================
//  Kemence Akadémia — AJÁNLAT e-mail küldő Edge Function (Deno / Supabase)
//
//  A FOGLALÁSTÓL FÜGGETLEN pár-ja a send-email-nek: az `ajanlatok` /
//  `ajanlat_sablonok` táblákra épül, és `ajanlat_log`-ba naplóz.
//
//  HÁROMFÉLE hívás (POST, JSON body):
//   1) NYERS teszt:  { "to":"cim@pl.hu", "subject":"Teszt", "text":"Szia" }
//   2) WEBHOOK (az ajanlatok INSERT trigger hívja):
//        { "type":"INSERT", "table":"ajanlatok", "record": { ... új ajánlat ... } }
//        → új ajánlatkérésnél AUTO: visszaigazoló (vendég) + csapat-értesítő (csapat).
//   3) SABLON/kézi (adminból): { "ajanlat_id":"<uuid>", "tipus":"ajanlat_megerosites" }
//        (opcionálisan { "targy":"...", "torzs":"..." } — adminban szerkesztett szöveg)
//        → beolvassa az ajánlatot + sablont, behelyettesít, elküldi (megerősítésnél
//          a privát bucketből a csatolmányt base64-ként mellékeli), naplóz.
//
//  Titkok (Supabase → Edge Functions → Secrets) — a send-email-lel közösek:
//    RESEND_API_KEY, MAIL_FROM, DEV_REDIRECT_TO (opcionális).
//    SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY automatikus.
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
const DEV_REDIRECT_TO = Deno.env.get("DEV_REDIRECT_TO") ?? "";

const CSATOLMANY_BUCKET = "ajanlat-csatolmanyok";

// {mezo} behelyettesítése
function behelyettesit(sablon: string, mezok: Record<string, unknown>): string {
  return String(sablon).replace(/\{(\w+)\}/g, (_, k) => String(mezok[k] ?? ""));
}
function formatDatum(iso: string | null): string {
  if (!iso) return "";
  return new Date(iso).toLocaleString("hu-HU", { dateStyle: "long", timeStyle: "short" });
}
function formatFt(n: unknown): string {
  if (n == null || n === "") return "";
  return Number(n).toLocaleString("hu-HU") + " Ft";
}
// ArrayBuffer → base64 (Resend csatolmányhoz)
function toBase64(buf: ArrayBuffer): string {
  const bytes = new Uint8Array(buf);
  let bin = "";
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin);
}

type Csatolmany = { filename: string; content: string };

// Egyetlen levél elküldése a Resend API-n át (opcionális csatolmányokkal).
async function kuld(to: string, subject: string, text: string, replyTo?: string, attachments?: Csatolmany[]): Promise<void> {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { "Authorization": `Bearer ${RESEND_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      from: MAIL_FROM,
      to: [to],
      subject,
      text,
      ...(replyTo ? { reply_to: replyTo } : {}),
      ...(attachments && attachments.length ? { attachments } : {}),
    }),
  });
  if (!res.ok) {
    const reszletek = await res.text();
    throw new Error(`Resend hiba (${res.status}): ${reszletek}`);
  }
}

// Egy ajánlathoz tartozó sablon-levél kiküldése + naplózás. Visszaadja a tényleges címzettet.
async function kuldSablon(
  db: ReturnType<typeof createClient>,
  ajanlat_id: string,
  tipus: string,
  targyIn?: unknown,
  torzsIn?: unknown,
): Promise<string> {
  const { data: a, error: ae } = await db
    .from("ajanlatok")
    .select("*, egyedi_programok ( cim )")
    .eq("id", ajanlat_id)
    .single();
  if (ae || !a) throw new Error("Az ajánlat nem található: " + ajanlat_id);

  const { data: beall } = await db
    .from("settings")
    .select("ajanlat_azonosito_elotag, ajanlat_azonosito_kezdo, levelezesi_email")
    .eq("id", 1).single();

  let targy: string, torzs: string;
  if (typeof targyIn === "string" && typeof torzsIn === "string") {
    targy = targyIn;
    torzs = torzsIn;
  } else {
    const { data: sablon } = await db
      .from("ajanlat_sablonok").select("targy, torzs").eq("tipus", tipus).single();
    if (!sablon) throw new Error("Nincs ilyen ajánlat-sablon: " + tipus);

    const elotag = (beall as any)?.ajanlat_azonosito_elotag ?? "A-";
    const kezdo  = Number((beall as any)?.ajanlat_azonosito_kezdo ?? 100);
    const azonosito = `${elotag}${Number((a as any).azonosito) + kezdo - 1}`;
    const mezok = {
      nev: (a as any).nev, email: (a as any).email, telefon: (a as any).telefon,
      program: (a as any).egyedi_programok?.cim ?? "Általános megkeresés",
      letszam: (a as any).letszam ?? "",
      kivant_idopont: formatDatum((a as any).kivant_idopont ?? null),
      keres_szoveg: (a as any).keres_szoveg ?? "",
      azonosito,
      vegleges_idopont: formatDatum((a as any).vegleges_idopont ?? null),
      vegleges_letszam: (a as any).vegleges_letszam ?? "",
      vegleges_ar: formatFt((a as any).vegleges_ar),
      ajanlat_szoveg: (a as any).ajanlat_szoveg ?? "",
    };
    targy = behelyettesit(sablon.targy, mezok);
    torzs = behelyettesit(sablon.torzs, mezok);
  }

  // A CSAPAT-értesítő a csapat címére megy, minden más a vendég címére.
  const csapatCim = (beall as any)?.levelezesi_email ?? "";
  const cimzett = tipus === "ajanlat_csapat_ertesito" ? csapatCim : (a as any).email;
  if (!cimzett) throw new Error("Nincs címzett (a csapat-értesítőhöz állítsd be a Csapat e-mail címet).");

  let replyTo = tipus === "ajanlat_csapat_ertesito" ? (a as any).email : (csapatCim || undefined);

  // Csatolmány CSAK a megerősítő levélhez, ha van feltöltve — a privát bucketből base64-ként.
  let attachments: Csatolmany[] | undefined;
  if (tipus === "ajanlat_megerosites" && (a as any).csatolmany_url) {
    const kulcs = (a as any).csatolmany_url as string;
    const { data: blob, error: de } = await db.storage.from(CSATOLMANY_BUCKET).download(kulcs);
    if (de) throw new Error("A csatolmány letöltése nem sikerült: " + de.message);
    const buf = await blob.arrayBuffer();
    attachments = [{ filename: kulcs.split("/").pop() || "csatolmany", content: toBase64(buf) }];
  }

  // Fejlesztői védelem: minden levél a DEV_REDIRECT_TO-ra, a valós címzett a tárgyban.
  let vegTargy = targy, vegCimzett = cimzett;
  if (DEV_REDIRECT_TO) {
    vegTargy = `[TESZT → ${cimzett}] ${targy}`;
    vegCimzett = DEV_REDIRECT_TO;
    replyTo = DEV_REDIRECT_TO;
  }

  await kuld(vegCimzett, vegTargy, torzs, replyTo, attachments);
  await db.from("ajanlat_log").insert({ ajanlat_id, tipus, cimzett });   // a szándékolt címzett
  return vegCimzett;
}

function valasz(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return valasz({ ok: false, error: "Csak POST." }, 405);

  try {
    if (!RESEND_API_KEY) throw new Error("Hiányzik a RESEND_API_KEY secret.");
    const body = await req.json().catch(() => ({}));

    // --- 1) NYERS teszt ---
    if (body.to && body.subject) {
      let to = body.to, subject = body.subject;
      if (DEV_REDIRECT_TO) { subject = `[TESZT → ${to}] ${subject}`; to = DEV_REDIRECT_TO; }
      await kuld(to, subject, body.text ?? "");
      return valasz({ ok: true, mode: "raw", to });
    }

    const db = createClient(SUPABASE_URL, SERVICE_ROLE);

    // --- 2) WEBHOOK: új ajánlatkérés → auto visszaigazoló + csapat-értesítő ---
    if (body.type === "INSERT" && body.table === "ajanlatok" && body.record && body.record.id) {
      const rec = body.record;
      if (rec.statusz && rec.statusz !== "ajanlatra_var") {
        return valasz({ ok: true, mode: "webhook", skipped: "nem ajanlatra_var" });
      }
      const eredmeny: Record<string, unknown> = { ok: true, mode: "webhook", ajanlat_id: rec.id };
      try { eredmeny.visszaigazolas = await kuldSablon(db, rec.id, "ajanlat_visszaigazolas"); }
      catch (e) { eredmeny.visszaigazolas_hiba = String((e as Error)?.message ?? e); }
      try { eredmeny.csapat_ertesito = await kuldSablon(db, rec.id, "ajanlat_csapat_ertesito"); }
      catch (e) { eredmeny.csapat_ertesito_hiba = String((e as Error)?.message ?? e); }
      return valasz(eredmeny);
    }

    // --- 3) SABLON/kézi: { ajanlat_id, tipus, (targy, torzs) } ---
    const { ajanlat_id, tipus, targy: targyIn, torzs: torzsIn } = body;
    if (!ajanlat_id || !tipus) {
      return valasz({ ok: false, error: "Adj meg { to, subject } vagy { ajanlat_id, tipus } (vagy webhook payload) mezőket." }, 400);
    }
    const to = await kuldSablon(db, ajanlat_id, tipus, targyIn, torzsIn);
    return valasz({ ok: true, mode: (typeof targyIn === "string" ? "custom" : "template"), tipus, to });
  } catch (e) {
    return valasz({ ok: false, error: String((e as Error)?.message ?? e) }, 500);
  }
});
