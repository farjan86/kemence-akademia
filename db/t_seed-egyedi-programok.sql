-- =====================================================================
--  t_ TECHNIKAI ESZKÖZ — néhány DEMO „egyedi program" a publikus
--  „Egyedi programok" blokk kipróbálásához.
--
--  NEM éles adat! A valós tartalmat az adminban (Egyedi programok menü,
--  3. fázis) viszed majd fel. Ez csak addig kell, amíg az admin CRUD nincs kész.
--
--  Idempotens: cím alapján nem szúr be kétszer. Töröld a demókat így:
--    delete from public.egyedi_programok where cim in
--      ('Leánybúcsú a kemencénél','Csapatépítő sütőnap','Szülinapi kemence-parti');
-- =====================================================================

insert into public.egyedi_programok (cim, rovid_leiras, leiras, sorrend)
select v.cim, v.rovid_leiras, v.leiras, v.sorrend
from (values
  ('Leánybúcsú a kemencénél',
   'Felejthetetlen délután a menyasszonynak és a barátnőknek — közös sütés, ízek, nevetés.',
   'Kézműves leánybúcsú a fatüzelésű kemence körül: közösen dagasztunk, formázunk és sütünk, miközben pezseg a jó hangulat. Az alkalmat a ti kívánságaitokhoz igazítjuk (létszám, menü, időtartam). Kérj ajánlatot, és összerakjuk a tökéletes napot!',
   10),
  ('Csapatépítő sütőnap',
   'Hozd el a csapatod egy közös kemencés élményre — pizza, kenyér és sok nevetés.',
   'A csapatépítő sütőnapon a kollégák közösen készítik el az ebédet a kemencében: tésztát gyúrnak, pizzát nyújtanak, kenyeret sütnek. Játékos, kézzelfogható program, ami tényleg összehozza a csapatot. Létszámtól függően szabjuk az ajánlatot.',
   20),
  ('Szülinapi kemence-parti',
   'Ünnepeld nálunk a szülinapot: mindenki süt, mindenki jóllakik.',
   'Szülinapi kemence-parti gyerekeknek vagy felnőtteknek: a vendégek maguk készítik és sütik meg a finomságokat, a végén pedig közösen lakmározunk. Rugalmas időpont és menü — mondd el, mire gondoltál, és személyre szabott ajánlattal jövünk.',
   30)
) as v(cim, rovid_leiras, leiras, sorrend)
where not exists (
  select 1 from public.egyedi_programok e where e.cim = v.cim
);
