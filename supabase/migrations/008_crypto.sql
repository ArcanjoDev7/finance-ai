create table public.crypto_assets (
 id uuid primary key default gen_random_uuid(), symbol text not null unique, name text not null, network text, decimals smallint not null default 8 check(decimals between 0 and 30),
 created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz
);
create trigger crypto_assets_set_updated_at before update on public.crypto_assets for each row execute function public.set_updated_at();
create table public.crypto_transactions (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict, account_id uuid not null references public.accounts(id) on delete restrict,
 crypto_asset_id uuid not null references public.crypto_assets(id) on delete restrict, transaction_id uuid unique references public.transactions(id) on delete restrict,
 operation_type public.crypto_operation_type not null, quantity numeric(30,12) not null check(quantity > 0), unit_price_minor bigint check(unit_price_minor >= 0), fee_minor bigint not null default 0 check(fee_minor >= 0),
 occurred_at timestamptz not null, created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz
);
create trigger crypto_transactions_set_updated_at before update on public.crypto_transactions for each row execute function public.set_updated_at();
