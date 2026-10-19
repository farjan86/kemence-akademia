-- =====================================================================
--  TARTALOM-EXPORT — a FORRÁS projektben futtasd (pl. a demóban)
--
--  Mit visz magával:  programok, időpontok, egyedi programok, előadók,
--                     program–előadó kapcsolatok, beállítások, levélsablonok
--  Mit NEM visz:      foglalások, ajánlatkérések, levélnaplók, látogatásszám
--                     (ezek az éles rendszerben tiszta lappal indulnak)
--
--  HASZNÁLAT
--    1. Supabase → SQL Editor → ezt a fájlt beilleszted → Run.
--    2. Az eredmény EGYETLEN cella, egy hosszú JSON szöveg.
--       Kattints a cellára, és másold ki a TELJES tartalmát.
--    3. Nyisd meg a `db/t_tartalom-import.sql` fájlt, és illeszd be oda,
--       ahová a megjegyzés mutatja. A többit az az írja le.
--
--  Csak olvas, semmit nem módosít. Bármikor újrafuttatható.
-- =====================================================================

select json_build_object(
  'keszult',          now(),
  'forras_projekt',   current_setting('request.jwt.claim.iss', true),

  'workshops',        (select coalesce(json_agg(t order by t.sorrend, t.cim), '[]'::json)
                         from public.workshops t),
  'idopontok',        (select coalesce(json_agg(t order by t.idopont), '[]'::json)
                         from public.idopontok t),
  'egyedi_programok', (select coalesce(json_agg(t order by t.sorrend, t.cim), '[]'::json)
                         from public.egyedi_programok t),
  'eloadok',          (select coalesce(json_agg(t order by t.sorrend, t.nev), '[]'::json)
                         from public.eloadok t),
  'program_eloadok',  (select coalesce(json_agg(t), '[]'::json)
                         from public.program_eloadok t),
  'settings',         (select coalesce(json_agg(t), '[]'::json)
                         from public.settings t),
  'email_sablonok',   (select coalesce(json_agg(t order by t.tipus), '[]'::json)
                         from public.email_sablonok t),
  'ajanlat_sablonok', (select coalesce(json_agg(t order by t.tipus), '[]'::json)
                         from public.ajanlat_sablonok t)
)::text as masold_ki_ezt;

-- ---------------------------------------------------------------------
--  Mellékesen: a képfájlok listája, hogy tudd, mit kell áttölteni.
--  A Supabase → Storage → program-fotok mappából ezeket töltsd le,
--  és az ÉLES projekt ugyanilyen nevű tárolójába töltsd fel UGYANAZZAL
--  a fájlnévvel. A webcímeket az import-szkript írja át.
-- ---------------------------------------------------------------------
select 'program'  as mihez, cim as nev, foto_url from public.workshops        where foto_url is not null
union all
select 'egyedi',             cim,       foto_url from public.egyedi_programok where foto_url is not null
union all
select 'előadó',             nev,       foto_url from public.eloadok          where foto_url is not null
order by mihez, nev;
