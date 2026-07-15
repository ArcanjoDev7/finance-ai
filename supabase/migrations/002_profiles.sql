create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete restrict,
  full_name text,
  avatar_path text,
  default_currency char(3) not null default 'BRL',
  locale text not null default 'pt-BR', timezone text not null default 'America/Sao_Paulo',
  theme text not null default 'system' check (theme in ('light','dark','system')),
  created_at timestamptz not null default timezone('utc', now()), updated_at timestamptz not null default timezone('utc', now()), deleted_at timestamptz
);
create trigger profiles_set_updated_at before update on public.profiles for each row execute function public.set_updated_at();

create or replace function public.create_profile_for_auth_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
 insert into public.profiles(user_id, full_name) values (new.id, coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'));
 return new;
end; $$;
create trigger auth_user_created after insert on auth.users for each row execute function public.create_profile_for_auth_user();
