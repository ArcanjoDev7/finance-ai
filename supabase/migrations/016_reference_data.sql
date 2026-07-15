create table public.currencies (
 id uuid primary key default gen_random_uuid(), code char(3) not null unique, name text not null, symbol text not null, decimal_places smallint not null default 2 check(decimal_places between 0 and 8),
 created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz
);
create trigger currencies_set_updated_at before update on public.currencies for each row execute function public.set_updated_at();
alter table public.currencies enable row level security;
create policy currencies_read on public.currencies for select to authenticated using (deleted_at is null);
