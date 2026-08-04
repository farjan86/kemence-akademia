-- =====================================================================
--  Kemence Akadémia — INDULÓ (kb. éles) programok  [ÚJ MODELL: időpontok]
--  A valódi kezdő workshopokat tölti fel: program (cím, leírások, előadó, kép)
--  + hozzájuk tartozó IDŐPONTOK (dátum, ár, kedvezményes ár, létszám).
--
--  HASZNÁLAT: a Supabase SQL Editorban futtasd.
--    ⚠️ RESET: előbb TÖRLI az ÖSSZES foglalást, időpontot ÉS programot, majd
--       újra létrehozza. ÉLES adaton NE futtasd!
--
--  ⚠️ NÉZD ÁT ÉS IGAZÍTSD a valós adatokra: ÁRAK, IDŐPONTOK, LÉTSZÁM, ELŐADÓ.
--  rovid_leiras = a kártyán megjelenő rövid szöveg (sima szöveg);
--  leiras       = a részletes leírás HTML-ben (félkövér/dőlt/felsorolás);
--  eloado       = előadó(k) neve (a kártyán „Előadó: …"); akár több név vesszővel.
--  Az ÁR / KEDVEZMÉNYES ÁR / LÉTSZÁM mostantól IDŐPONTONKÉNT értendő.
--  A foto_url a helyi képekre mutat (/kepek/...); az admin később felülírhatja.
-- =====================================================================

-- ⚠️ RESET: minden foglalás, időpont és program törlése, majd újra létrehozás
truncate table public.email_log, public.bookings, public.idopontok, public.workshops
  restart identity cascade;

do $$
declare
  w_csiga  uuid;
  w_pizza  uuid;
  w_kovasz uuid;
begin
  -- 1) Kakaós csiga - gyermektábor (1 időpont)
  insert into public.workshops (cim, rovid_leiras, leiras, eloado, varhato_idotartam, foto_url, statusz, archivalt)
  values ('Kakaós csiga - gyermektábor',
    'A gyerekek a táborban saját kezűleg gyúrják, töltik és tekerik a kakaós csigát, majd a fatüzelésű kemencében sütjük ki.',
    '<p>A gyerekek egyik nagy kedvence, puha kelt tésztából, bőséges kakaós töltelékkel és azzal a semmivel össze nem téveszthető, frissen sült illattal. A táborban a kicsik saját kezűleg gyúrják, töltik és tekerik fel a csigákat, majd együtt sütjük ki őket a fatüzelésű kemencében. A saját maguk készített, még meleg kakaós csiga íze garantáltan felejthetetlen élmény.</p>',
    null, 'kb. 3 óra', '/kepek/csiga.jpg', 'aktiv', false)
  returning id into w_csiga;

  insert into public.idopontok (workshop_id, idopont, ar, kedvezmenyes_ar, max_letszam)
  values (w_csiga, timestamptz '2026-08-12 09:00+02', 6000, null, 6);

  -- 2) Nápolyi Pizza Workshop Szabó Zolival (1 időpont)
  insert into public.workshops (cim, rovid_leiras, leiras, eloado, varhato_idotartam, foto_url, statusz, archivalt)
  values ('Nápolyi Pizza Workshop Szabó Zolival',
    'Igazi nápolyi pizza a kemencéből: tészta-kelesztés, nyújtás, feltétek és a sütés fortélyai. Mindenki több saját pizzát is süt és megkóstol. A vacsora ára az árban benne van.',
    '<p><strong>Pizza Workshop – Kemencés Nápolyi Pizza készítés Olasz Caputo alapanyagokkal</strong></p>
<p>Ismerd meg a kemencés nápolyi pizza készítésének teljes folyamatát egy kis létszámú (4–5 fős), családias hangulatú workshop keretében. A képzés során elméleti és gyakorlati oktatás keretében sajátíthatod el a pizzakészítés és a fatüzelésű kemencében történő sütés alapjait.</p>
<p>A workshop során bemutatjuk:</p>
<ul>
<li>a pizzatészta alapanyagait és az alapvető fogalmakat,</li>
<li>az előfermentált tészta elkészítését,</li>
<li>a tészta dagasztását és a háromfázisú kelesztés folyamatát,</li>
<li>a tészta nyújtását, formázását és a helyes feltétezést,</li>
<li>a sütéshez szükséges hőmérsékletet, sütési időt, valamint a pizza vetésének és szedésének technikáját,</li>
<li>a fatüzelésű kerti kemencék működését, felfűtését és az alkalmazható tűzifák típusait.</li>
</ul>
<p>A gyakorlati bemutató során a résztvevők megismerkednek a kemencében történő sütés folyamatával, valamint a kemencék kezelésével. A workshop végére nemcsak a pizzakészítés technikáit sajátítják el, hanem átfogó ismereteket szereznek a fatüzelésű kemencék használatáról is.</p>
<p>A rendezvény teljes időtartama alatt kávét, teát és frissítőket biztosítunk.</p>
<p><strong>A workshop végén minden résztvevő az alábbiakat viheti haza:</strong></p>
<ul>
<li>recept,</li>
<li>2 db pizzabuci, amelyet otthon a tanultak alapján süthet meg,</li>
<li>Kemence Akadémiás kötény.</li>
</ul>
<p>A workshop végén lehetőség nyílik a felmerülő kérdések megbeszélésére, online mentori segítség igénybevételére, valamint a használt konyhai eszközök, kemencék és kerti konyhák megvásárlására vagy megrendelésére.</p>',
    'Szabó Zoltán', 'kb. 5 óra', '/kepek/kemences_pizza_workshop.jpg', 'aktiv', false)
  returning id into w_pizza;

  insert into public.idopontok (workshop_id, idopont, ar, kedvezmenyes_ar, max_letszam)
  values (w_pizza, timestamptz '2026-08-14 16:00+02', 20000, null, 5);

  -- 3) Kovászos Kenyér és Kalács Workshop Andival (KÉT időpont — az új képesség demója)
  insert into public.workshops (cim, rovid_leiras, leiras, eloado, varhato_idotartam, foto_url, statusz, archivalt)
  values ('Kovászos Kenyér és Kalács Workshop Andival',
    'Kemencés kalács és kenyér vadkovászos tésztából, felejtsd el az élesztőt! Illatos, finom és egészséges házi kenyerek.',
    '<p><strong>Élesztős és kovászos tészták Workshop – Kemencés kenyér és kalács</strong></p>
<p>Ismerd meg a kemencében sült kenyerek és kalácsok készítésének fortélyait egy családias hangulatú, 4–5 fős workshop keretében. A képzés során betekintést nyerhetsz az élesztős és a kovászos tészták készítésének folyamataiba, valamint a fatüzelésű kemencében történő sütés alapjaiba.</p>
<p>A workshop során megismerheted:</p>
<ul>
<li>a kenyér- és kalácstészták alapanyagait,</li>
<li>a különböző formázási lehetőségeket és töltelékeket,</li>
<li>a hozzávalók előkészítését és a kézi dagasztás folyamatát,</li>
<li>a hajtogatás, nyújtás és formázás technikáit,</li>
<li>a fatüzelésű kemence felfűtését, működését, valamint a sütési hőmérsékletet, időt és kemencés sütési technikákat.</li>
</ul>
<p>A workshop során közösen készítjük el a tésztákat, figyelemmel kísérjük azok érési folyamatát, majd kemencében sütjük meg a kenyereket és a kalácsokat, amelyeket együtt el is fogyasztunk. A foglalkozás teljes ideje alatt lehetőség van kérdezni és tapasztalatot cserélni.</p>
<p>A kovászos workshop reggel 8:00 órától körülbelül 16:00 óráig, az élesztős workshop 8:00 órától körülbelül 13:00 óráig tart. Kérjük, néhány perccel a kezdés előtt érkezz.</p>
<p><strong>A workshop végén minden résztvevő hazaviheti a Kemence Akadémiás kötényt, amelyet a foglalkozás során használt.</strong></p>
<p><strong>A kovászos workshop résztvevői ezen felül kapnak:</strong></p>
<ul>
<li>kenyér- és kalácsreceptet,</li>
<li>kovászt,</li>
<li>egy kisült kenyeret,</li>
<li>egy kisült kalácsot,</li>
<li>valamint a tanfolyamon dagasztott tésztát, amelyet otthon kell befejezni.</li>
</ul>
<p><strong>Az élesztős workshop résztvevői ezen felül kapnak:</strong></p>
<ul>
<li>recepteket,</li>
<li>az általuk készített kenyeret,</li>
<li>az általuk készített édes kelt finomságot (a tanfolyamtól függően változhat),</li>
<li>számukra nincs otthoni feladat.</li>
</ul>
<p>A rendezvény teljes időtartama alatt kávét, teát és frissítőket biztosítunk.</p>
<p>A workshop végén lehetőség nyílik a nap során használt konyhai eszközök megvásárlására, valamint kemencék és kerti konyhák megrendelésére.</p>',
    'Nagy Andrea', 'kb. 7 óra', '/kepek/kovaszos_tesztak_workshop.jpg', 'aktiv', false)
  returning id into w_kovasz;

  insert into public.idopontok (workshop_id, idopont, ar, kedvezmenyes_ar, max_letszam)
  values
    (w_kovasz, timestamptz '2026-08-15 08:00+02', 20000, null, 5),
    (w_kovasz, timestamptz '2026-09-12 08:00+02', 20000, null, 5);
end $$;

-- Ellenőrzés: program × időpont
select cim,
       coalesce(to_char(idopont, 'YYYY-MM-DD HH24:MI'), '(nincs időpont)') as idopont,
       eloado, ar, max_letszam, szabad_helyek
from public.programok
order by cim, idopont nulls last;
