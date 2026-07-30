-- =====================================================================
--  Migráció: a foglalási info-sáv szövege az admin által állítható
--  legyen (settings.foglalas_infosav). Futtasd a már meglévő DB-n.
-- =====================================================================
alter table public.settings
  add column if not exists foglalas_infosav text;

update public.settings
  set foglalas_infosav =
    'A foglalás jóváhagyásához előre utalás szükséges. Beküldés után felvesszük veled a kapcsolatot; a foglalás addig „jóváhagyásra vár” állapotban van.'
  where id = 1 and foglalas_infosav is null;
