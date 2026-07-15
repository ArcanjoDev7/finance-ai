create table public.category_templates (
 id uuid primary key default gen_random_uuid(), name text not null, transaction_kind public.transaction_type not null,
 icon_key text, display_order smallint not null default 0, unique(name, transaction_kind)
);
create table public.categories (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict,
 parent_id uuid references public.categories(id) on delete restrict, name text not null, transaction_kind public.transaction_type not null,
 icon_key text, color_hex text check (color_hex is null or color_hex ~ '^#[0-9A-Fa-f]{6}$'), is_system boolean not null default false,
 created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz,
 unique(user_id, parent_id, name, transaction_kind)
);
create trigger categories_set_updated_at before update on public.categories for each row execute function public.set_updated_at();

create or replace function public.seed_categories_for_profile()
returns trigger language plpgsql security definer set search_path = public as $$
begin
 insert into public.categories(user_id,name,transaction_kind,icon_key,is_system)
 select new.user_id,name,transaction_kind,icon_key,true from public.category_templates;
 return new;
end; $$;
create trigger profile_categories_created after insert on public.profiles for each row execute function public.seed_categories_for_profile();
