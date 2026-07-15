create table public.wallets (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict,
 name text not null check (char_length(name) between 1 and 100), wallet_type text not null default 'personal', currency_code char(3) not null default 'BRL',
 is_archived boolean not null default false, created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz,
 unique (user_id, name)
);
create trigger wallets_set_updated_at before update on public.wallets for each row execute function public.set_updated_at();

create table public.accounts (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict,
 wallet_id uuid not null references public.wallets(id) on delete restrict, name text not null, institution_name text, branch_code text, account_number text,
 account_type text not null check (account_type in ('checking','savings','cash','brokerage','crypto_wallet','international')),
 currency_code char(3) not null default 'BRL', opening_balance_minor bigint not null default 0, current_balance_minor bigint not null default 0,
 created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz,
 unique(user_id, wallet_id, name)
);
create trigger accounts_set_updated_at before update on public.accounts for each row execute function public.set_updated_at();
