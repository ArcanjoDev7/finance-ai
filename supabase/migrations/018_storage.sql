insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
 ('transaction-attachments','transaction-attachments',false,10485760,array['application/pdf','image/jpeg','image/png','image/webp']),
 ('avatars','avatars',false,2097152,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=excluded.public,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

create policy "attachment owner read" on storage.objects for select to authenticated using (bucket_id='transaction-attachments' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "attachment owner insert" on storage.objects for insert to authenticated with check (bucket_id='transaction-attachments' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "attachment owner update" on storage.objects for update to authenticated using (bucket_id='transaction-attachments' and (storage.foldername(name))[1]=auth.uid()::text) with check (bucket_id='transaction-attachments' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "attachment owner delete" on storage.objects for delete to authenticated using (bucket_id='transaction-attachments' and (storage.foldername(name))[1]=auth.uid()::text);

create policy "avatar owner read" on storage.objects for select to authenticated using (bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "avatar owner insert" on storage.objects for insert to authenticated with check (bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "avatar owner update" on storage.objects for update to authenticated using (bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text) with check (bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "avatar owner delete" on storage.objects for delete to authenticated using (bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);
