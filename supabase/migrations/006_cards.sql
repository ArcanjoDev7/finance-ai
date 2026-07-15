create table public.cards (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict,
 account_id uuid not null references public.accounts(id) on delete restrict, name text not null, institution_name text, last_four char(4),
 credit_limit_minor bigint not null check(credit_limit_minor >= 0), available_limit_minor bigint not null check(available_limit_minor >= 0),
 closing_day smallint not null check(closing_day between 1 and 31), due_day smallint not null check(due_day between 1 and 31), currency_code char(3) not null default 'BRL',
 created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz
);
create trigger cards_set_updated_at before update on public.cards for each row execute function public.set_updated_at();
create table public.card_invoices (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict, card_id uuid not null references public.cards(id) on delete restrict,
 reference_month date not null check(reference_month = date_trunc('month',reference_month)::date), closing_at timestamptz not null, due_at timestamptz not null,
 total_minor bigint not null default 0, status public.transaction_status not null default 'pending', payment_transaction_id uuid references public.transactions(id) on delete restrict,
 created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz, unique(card_id,reference_month)
);
create trigger card_invoices_set_updated_at before update on public.card_invoices for each row execute function public.set_updated_at();
create table public.card_transactions (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict, card_id uuid not null references public.cards(id) on delete restrict,
 transaction_id uuid not null unique references public.transactions(id) on delete restrict, card_invoice_id uuid references public.card_invoices(id) on delete restrict,
 installment_count smallint not null default 1 check(installment_count > 0), installment_number smallint not null default 1 check(installment_number > 0), installment_amount_minor bigint not null check(installment_amount_minor > 0),
 created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz,
 check(installment_number <= installment_count)
);
create trigger card_transactions_set_updated_at before update on public.card_transactions for each row execute function public.set_updated_at();
