create table public.investment_types (
 id uuid primary key default gen_random_uuid(), code text not null unique, name text not null unique, is_active boolean not null default true,
 created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz
);
create trigger investment_types_set_updated_at before update on public.investment_types for each row execute function public.set_updated_at();
create table public.investments (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict, account_id uuid not null references public.accounts(id) on delete restrict,
 investment_type_id uuid not null references public.investment_types(id) on delete restrict, transaction_id uuid unique references public.transactions(id) on delete restrict,
 name text not null, institution_name text, yield_description text, liquidity_description text, maturity_on date,
 invested_amount_minor bigint not null check(invested_amount_minor >= 0), current_amount_minor bigint not null check(current_amount_minor >= 0),
 created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz
);
create trigger investments_set_updated_at before update on public.investments for each row execute function public.set_updated_at();
