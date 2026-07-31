-- =====================================================================
--  Migráció: Storage tároló a program-fotóknak.
--  Publikusan OLVASHATÓ (a képek a weboldalon megjelennek), írni csak
--  a bejelentkezett admin tud. Futtasd a Supabase SQL Editorban.
--
--  Ha a policy-k létrehozása jogosultsági hibát ad, hozd létre a bucketet
--  a Storage felületen: New bucket → név: program-fotok → Public → Create.
-- =====================================================================

-- A bucket (publikus)
insert into storage.buckets (id, name, public)
values ('program-fotok', 'program-fotok', true)
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
