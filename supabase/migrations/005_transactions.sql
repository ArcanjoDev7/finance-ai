create table public.transactions (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict,
 wallet_id uuid not null references public.wallets(id) on delete restrict, account_id uuid references public.accounts(id) on delete restrict,
 destination_account_id uuid references public.accounts(id) on delete restrict, category_id uuid references public.categories(id) on delete restrict,
 amount_minor bigint not null check (amount_minor > 0), currency_code char(3) not null default 'BRL', description text not null default '',
 transaction_type public.transaction_type not null, status public.transaction_status not null default 'paid', payment_method public.payment_method,
 occurred_at timestamptz not null, idempotency_key uuid, metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz,
 check ((transaction_type = 'transfer') = (destination_account_id is not null)),
 unique(user_id, idempotency_key)
);
create trigger transactions_set_updated_at before update on public.transactions for each row execute function public.set_updated_at();
create table public.transaction_attachments (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict,
 transaction_id uuid not null references public.transactions(id) on delete restrict, storage_path text not null, file_name text not null, content_type text not null,
 created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz
);
create trigger transaction_attachments_set_updated_at before update on public.transaction_attachments for each row execute function public.set_updated_at();
