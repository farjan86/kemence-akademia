-- =====================================================================
--  Migráció: Storage tároló a program-fotóknak.
--  Publikusan OLVASHATÓ (a képek a weboldalon megjelennek), írni csak
--  a bejelentkezett admin tud. Futtasd a Supabase SQL Editorban.
--
--  Ha a policy-k létrehozása jogosultsági hibát ad, hozd létre a bucketet
--  a Storage felületen: New bucket → név: program-fotok → Public → Create.
-- =====================================================================

-- A bucket (publikus)
-- file_size_limit (bájt) + allowed_mime_types: SZERVEROLDALI korlát — a kliens
-- JS-ben lévő ellenőrzés csak kényelmi, API-n keresztül megkerülhető lenne.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('program-fotok', 'program-fotok', true, 10485760,   -- 10 MB
        array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do nothing;

-- Feltöltés / módosítás / törlés: csak bejelentkezett admin ehhez a buckethez
drop policy if exists "program_fotok_admin_ins" on storage.objects;
create policy "program_fotok_admin_ins" on storage.objects
  for insert to authenticated with check (bucket_id = 'program-fotok');

drop policy if exists "program_fotok_admin_upd" on storage.objects;
create policy "program_fotok_admin_upd" on storage.objects
  for update to authenticated using (bucket_id = 'program-fotok');

drop policy if exists "program_fotok_admin_del" on storage.objects;
create policy "program_fotok_admin_del" on storage.objects
  for delete to authenticated using (bucket_id = 'program-fotok');

-- Olvasás: publikus (a bucket public flagje miatt a publikus URL működik).
drop policy if exists "program_fotok_read" on storage.objects;
create policy "program_fotok_read" on storage.objects
  for select using (bucket_id = 'program-fotok');

-- =====================================================================
--  PRIVÁT bucket az AJÁNLAT-CSATOLMÁNYOKNAK (pdf/docx/kép a megerősítő levélhez).
--  NEM publikus: sem feltöltés, sem olvasás nincs anon módon. Csak a bejelentkezett
--  admin tölt fel/olvas; a send-ajanlat-email a service-role kulccsal éri el.
--
--  Ha a policy-k jogosultsági hibát adnak, hozd létre a Storage felületen:
--    New bucket → név: ajanlat-csatolmanyok → PRIVATE (public KIKAPCSOLVA) → Create.
-- =====================================================================
-- file_size_limit (bájt) + allowed_mime_types: lásd a program-fotok megjegyzését.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('ajanlat-csatolmanyok', 'ajanlat-csatolmanyok', false, 20971520,   -- PRIVÁT, 20 MB
        array['application/pdf','image/jpeg','image/png',
              'application/msword',
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
              'text/plain'])
on conflict (id) do nothing;

drop policy if exists "ajanlat_csat_admin_ins" on storage.objects;
create policy "ajanlat_csat_admin_ins" on storage.objects
  for insert to authenticated with check (bucket_id = 'ajanlat-csatolmanyok');

drop policy if exists "ajanlat_csat_admin_upd" on storage.objects;
create policy "ajanlat_csat_admin_upd" on storage.objects
  for update to authenticated using (bucket_id = 'ajanlat-csatolmanyok');

drop policy if exists "ajanlat_csat_admin_del" on storage.objects;
create policy "ajanlat_csat_admin_del" on storage.objects
  for delete to authenticated using (bucket_id = 'ajanlat-csatolmanyok');

-- Olvasás: CSAK admin (nincs publikus select — privát bucket).
drop policy if exists "ajanlat_csat_admin_read" on storage.objects;
create policy "ajanlat_csat_admin_read" on storage.objects
  for select to authenticated using (bucket_id = 'ajanlat-csatolmanyok');
