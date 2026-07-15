alter type public.crypto_operation_type add value if not exists 'transfer_in';
alter type public.crypto_operation_type add value if not exists 'transfer_out';
alter type public.crypto_operation_type add value if not exists 'unstaking';
alter type public.crypto_operation_type add value if not exists 'airdrop';
alter type public.crypto_operation_type add value if not exists 'fee';
alter type public.crypto_operation_type add value if not exists 'adjustment';

create table public.crypto_exchanges (
 id uuid primary key default gen_random_uuid(), name text not null unique, website_url text,
 created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz
);
create trigger crypto_exchanges_set_updated_at before update on public.crypto_exchanges for each row execute function public.set_updated_at();

alter table public.crypto_transactions
 add column wallet_id uuid references public.wallets(id) on delete restrict,
 add column exchange_id uuid references public.crypto_exchanges(id) on delete restrict,
 add column transfer_group_id uuid,
 add column transaction_hash text,
 add column fee_currency_code char(3),
 add column network_fee numeric(30,12) check(network_fee >= 0),
 add column notes text;
create index crypto_transactions_transfer_group_idx on public.crypto_transactions(user_id,transfer_group_id) where deleted_at is null;

alter table public.crypto_exchanges enable row level security;
create policy crypto_exchanges_read on public.crypto_exchanges for select to authenticated using(deleted_at is null);
