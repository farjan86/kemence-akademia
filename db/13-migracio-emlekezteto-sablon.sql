-- =====================================================================
--  Migráció: „Emlékeztető" e-mail sablon
--
--  A program ELŐTTI NAPON a vendégeknek kiküldendő emlékeztető levél
--  sablonja. A típus (`emlekezteto`) a séma CHECK-jében már engedélyezett
--  volt, csak a sablon-sor hiányzott.
--
--  A tényleges küldést majd a levélküldő háttér + napi ütemező (pg_cron)
--  végzi — ez a fájl csak a szerkeszthető sablont hozza létre.
--  A 01-schema.sql már tartalmazza ezt a sort (üres telepítésnél ott van).
-- =====================================================================

insert into public.email_sablonok (tipus, targy, torzs) values
('emlekezteto',
 'Emlékeztető: holnap {program} – Kemence Akadémia ({azonosito})',
 E'Kedves {nev}!\n\nEmlékeztetünk, hogy holnap, {idopont} időpontban kerül megrendezésre a(z) {program}, amelyre {letszam} fő jelentkezésedet rögzítettük.\n\nSzeretettel várunk! Ha bármi közbejött, kérjük mielőbb jelezd a válasz e-mailben.\n\nFoglalási azonosító: {azonosito}\n\nÜdvözlettel,\nKemence Akadémia')
on conflict (tipus) do nothing;
