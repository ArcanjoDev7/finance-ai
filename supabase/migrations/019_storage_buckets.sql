insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types) values
 ('receipts','receipts',false,10485760,array['application/pdf','image/jpeg','image/png','image/webp']),
 ('attachments','attachments',false,10485760,array['application/pdf','image/jpeg','image/png','image/webp']),
 ('documents','documents',false,10485760,array['application/pdf','image/jpeg','image/png','image/webp']),
 ('exports','exports',false,52428800,array['application/pdf','text/csv','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'])
on conflict (id) do update set public=excluded.public,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

do $$
declare bucket text;
begin
 foreach bucket in array array['receipts','attachments','documents','exports'] loop
   execute format('create policy %I on storage.objects for select to authenticated using (bucket_id=%L and (storage.foldername(name))[1]=auth.uid()::text)', bucket || ' owner read', bucket);
   execute format('create policy %I on storage.objects for insert to authenticated with check (bucket_id=%L and (storage.foldername(name))[1]=auth.uid()::text)', bucket || ' owner insert', bucket);
   execute format('create policy %I on storage.objects for update to authenticated using (bucket_id=%L and (storage.foldername(name))[1]=auth.uid()::text) with check (bucket_id=%L and (storage.foldername(name))[1]=auth.uid()::text)', bucket || ' owner update', bucket, bucket);
   execute format('create policy %I on storage.objects for delete to authenticated using (bucket_id=%L and (storage.foldername(name))[1]=auth.uid()::text)', bucket || ' owner delete', bucket);
 end loop;
end $$;
