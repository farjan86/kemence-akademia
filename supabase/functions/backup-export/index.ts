// =====================================================================
//  Kemence Akadémia — HETI ADATMENTÉS e-mailben (Deno / Supabase Edge Function)
//
//  Kiolvassa a public séma MINDEN adattáblájának MINDEN sorát (archiváltakkal,
//  lezártakkal, naplókkal együtt), táblánként egy CSV-t készít, az egészet
//  EGY ZIP-be csomagolja, és egy levélben, csatolmányként elküldi a csapat
//  címére (Beállítások → „Csapat e-mail cím").
//
//  Ami NINCS benne (nem az adatbázis-táblákban él):
//    - a kép- és csatolmány-FÁJLOK (Supabase Storage) — a rájuk mutató
//      hivatkozás (foto_url, csatolmany_url) a CSV-ben benne van;
//    - az admin belépési fiókok (Supabase Auth) — azokat a Supabase felületén
//      kell újra felvenni.
//
//  HÍVÁS (POST, üres vagy {} body). Két fejléc kell:
//    Authorization: Bearer <ANON_KEY>     — a Supabase kapu JWT-ellenőrzéséhez
//    x-backup-key:  <BACKUP_SECRET>       — a MI kapunk: ezt csak a cron ismeri
//  Az időzítést a db/05-heti-mentes-cron.sql adja (pg_cron + pg_net).
//
//  Titkok (Supabase → Edge Functions → Secrets):
//    RESEND_API_KEY   a Resend API-kulcsa (a send-email-lel közös)
//    MAIL_FROM        feladó (a send-email-lel közös)
//    BACKUP_SECRET    tetszőleges hosszú, véletlen szöveg — ugyanez kerül a cron SQL-be
//    DEV_REDIRECT_TO  (opcionális) fejlesztői védelem — a levél csak erre a címre megy
//  A SUPABASE_URL és a SUPABASE_SERVICE_ROLE_KEY automatikusan elérhető.
//
//  CSV-formátum: UTF-8 BOM-mal, pontosvessző elválasztó, CRLF sorvég — így a
//  magyar beállítású Excel dupla kattintással, helyes ékezetekkel nyitja.
//  Az értékek nyersen mennek (true/false, ISO-dátum, uuid, JSON szövegként):
//  egy visszatöltő SQL-nek így a legegyszerűbb. Részletek: docs/heti-mentes.md
// =====================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { zipSync, strToU8 } from "https://esm.sh/fflate@0.8.2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-backup-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const RESEND_API_KEY  = Deno.env.get("RESEND_API_KEY") ?? "";
const MAIL_FROM       = Deno.env.get("MAIL_FROM") ?? "Kemence Akadémia <onboarding@resend.dev>";
const SUPABASE_URL    = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE    = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const BACKUP_SECRET   = Deno.env.get("BACKUP_SECRET") ?? "";
const DEV_REDIRECT_TO = Deno.env.get("DEV_REDIRECT_TO") ?? "";

// A mentett táblák — a public séma ÖSSZES adattáblája, a visszatöltés
// sorrendjében (előbb az, amire a többi hivatkozik). `rendez`: az oszlop,
// ami szerint a sorok sorba kerülnek, hogy két mentés összehasonlítható legyen.
const TABLAK: { nev: string; rendez?: string }[] = [
  { nev: "workshops",         rendez: "sorrend" },
  { nev: "idopontok",         rendez: "idopont" },
  { nev: "eloadok",           rendez: "sorrend" },
  { nev: "program_eloadok",   rendez: "workshop_id" },
  { nev: "egyedi_programok",  rendez: "sorrend" },
  { nev: "bookings",          rendez: "created_at" },
  { nev: "ajanlatok",         rendez: "created_at" },
  { nev: "email_log",         rendez: "elkuldve" },
  { nev: "ajanlat_log",       rendez: "elkuldve" },
  { nev: "settings" },
  { nev: "email_sablonok" },
  { nev: "ajanlat_sablonok" },
  { nev: "oldal_statisztika" },
];

// A PostgREST egy kérésre legfeljebb 1000 sort ad — ezért lapozva olvasunk,
// különben a foglalások egy idő után némán csonkulnának.
const LAP = 1000;

type Sor = Record<string, unknown>;

async function teljesTabla(db: ReturnType<typeof createClient>, nev: string, rendez?: string): Promise<Sor[]> {
  const sorok: Sor[] = [];
  for (let tol = 0; ; tol += LAP) {
    let q = db.from(nev).select("*").range(tol, tol + LAP - 1);
    if (rendez) q = q.order(rendez, { ascending: true });
    const { data, error } = await q;
    if (error) throw new Error(`${nev}: ${error.message}`);
    sorok.push(...(data ?? []));
    if (!data || data.length < LAP) break;
  }
  return sorok;
}

// Egy CSV-mező: üres a NULL; idézőjelbe kerül, ha elválasztót, idézőjelet
// vagy sortörést tartalmaz (az idézőjel duplázva). A JSON-mezők szövegként.
function csvMezo(v: unknown): string {
  if (v === null || v === undefined) return "";
  const s = typeof v === "object" ? JSON.stringify(v) : String(v);
  return /[;"\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

function csv(sorok: Sor[]): string {
  const BOM = "﻿";
  if (!sorok.length) return BOM + "(nincs adat)\r\n";
  const oszlopok = Object.keys(sorok[0]);   // select * → minden sorban ugyanazok az oszlopok
  const sorokSzoveg = [
    oszlopok.map(csvMezo).join(";"),
    ...sorok.map((r) => oszlopok.map((k) => csvMezo(r[k])).join(";")),
  ];
  return BOM + sorokSzoveg.join("\r\n") + "\r\n";
}

// Bájtok → base64 (Resend csatolmányhoz). Darabolva, hogy nagy fájlnál se
// fusson ki a hívási verem.
function toBase64(bytes: Uint8Array): string {
  let bin = "";
  for (let i = 0; i < bytes.length; i += 0x8000) {
    bin += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  return btoa(bin);
}

async function kuld(to: string, subject: string, text: string, filename: string, content: string): Promise<void> {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { "Authorization": `Bearer ${RESEND_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: MAIL_FROM, to: [to], subject, text, attachments: [{ filename, content }] }),
  });
  if (!res.ok) throw new Error(`Resend hiba (${res.status}): ${await res.text()}`);
}

function valasz(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return valasz({ ok: false, error: "Csak POST." }, 405);

  try {
    if (!RESEND_API_KEY) throw new Error("Hiányzik a RESEND_API_KEY secret.");
    if (!BACKUP_SECRET)  throw new Error("Hiányzik a BACKUP_SECRET secret.");

    // A mi kapunk: a titkos kulcs nélkül senki nem válthat ki mentés-levelet,
    // akkor sem, ha a (publikus) anon kulcsot ismeri.
    if ((req.headers.get("x-backup-key") ?? "") !== BACKUP_SECRET) {
      return valasz({ ok: false, error: "Nincs jogosultság." }, 401);
    }

    const db = createClient(SUPABASE_URL, SERVICE_ROLE);

    // Címzett: a Beállításokban megadott csapat-cím.
    const { data: beall } = await db.from("settings").select("levelezesi_email").eq("id", 1).maybeSingle();
    const cimzett = (beall?.levelezesi_email ?? "").trim();
    if (!cimzett) throw new Error("Nincs címzett: állítsd be a Csapat e-mail címet az admin Beállítások fülén.");

    // Dátum a fájlnévhez és a tárgyhoz, budapesti idő szerint (ÉÉÉÉ-HH-NN).
    const datum = new Date().toLocaleDateString("sv-SE", { timeZone: "Europe/Budapest" });

    // Táblánként egy CSV, az egész egy ZIP-ben.
    const fajlok: Record<string, Uint8Array> = {};
    const darab: Record<string, number> = {};
    for (const t of TABLAK) {
      const sorok = await teljesTabla(db, t.nev, t.rendez);
      fajlok[`${t.nev}.csv`] = strToU8(csv(sorok));
      darab[t.nev] = sorok.length;
    }
    const zip = zipSync(fajlok, { level: 6 });
    const zipNev = `kemence-mentes-${datum}.zip`;

    const targy = `Adatmentés ${datum} — ${darab.bookings} foglalás, ${darab.ajanlatok} ajánlat`;
    const torzs = `Kemence Akadémia — adatmentés, ${datum}\nCsatolva: ${zipNev} (${TABLAK.length} CSV, ${(zip.length / 1024).toFixed(0)} KB)\n`;

    // Fejlesztői védelem: minden levél a DEV_REDIRECT_TO címre, a valós címzett a tárgyban.
    let vegCimzett = cimzett, vegTargy = targy;
    if (DEV_REDIRECT_TO) { vegCimzett = DEV_REDIRECT_TO; vegTargy = `[TESZT → ${cimzett}] ${targy}`; }

    await kuld(vegCimzett, vegTargy, torzs, zipNev, toBase64(zip));
    console.log(`Adatmentés elküldve: ${vegCimzett}, ${zipNev}, ${zip.length} bájt`);
    return valasz({ ok: true, to: vegCimzett, datum, zip: zipNev, bajt: zip.length, tablak: darab });
  } catch (e) {
    console.error("Adatmentés HIBA:", e);
    return valasz({ ok: false, error: String((e as Error)?.message ?? e) }, 500);
  }
});
