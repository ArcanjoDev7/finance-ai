create type public.card_invoice_status as enum ('open','closed','partially_paid','paid','overdue','cancelled');
alter table public.card_invoices add column paid_amount_minor bigint not null default 0 check(paid_amount_minor >= 0), add column paid_at timestamptz, add column invoice_status public.card_invoice_status not null default 'open';

create table public.card_purchases (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict, card_id uuid not null references public.cards(id) on delete restrict,
 transaction_id uuid not null unique references public.transactions(id) on delete restrict, category_id uuid references public.categories(id) on delete restrict,
 description text not null, merchant_name text, total_amount_minor bigint not null check(total_amount_minor > 0), purchase_at timestamptz not null, notes text,
 original_purchase_id uuid references public.card_purchases(id) on delete restrict, created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz
);
create trigger card_purchases_set_updated_at before update on public.card_purchases for each row execute function public.set_updated_at();

create table public.installment_plans (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict, card_id uuid not null references public.cards(id) on delete restrict, card_purchase_id uuid not null unique references public.card_purchases(id) on delete restrict,
 total_amount_minor bigint not null check(total_amount_minor > 0), installment_count smallint not null check(installment_count > 0), start_at timestamptz not null, status text not null default 'active' check(status in ('active','completed','cancelled')),
 created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz
);
create trigger installment_plans_set_updated_at before update on public.installment_plans for each row execute function public.set_updated_at();

create table public.installments (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict, installment_plan_id uuid not null references public.installment_plans(id) on delete restrict, card_invoice_id uuid not null references public.card_invoices(id) on delete restrict,
 installment_number smallint not null, installment_total smallint not null, amount_minor bigint not null check(amount_minor > 0), due_at timestamptz not null, status public.card_invoice_status not null default 'open',
 created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz, unique(installment_plan_id,installment_number), check(installment_number between 1 and installment_total)
);
create trigger installments_set_updated_at before update on public.installments for each row execute function public.set_updated_at();

alter table public.card_purchases enable row level security; alter table public.installment_plans enable row level security; alter table public.installments enable row level security;
do $$ declare tab text; begin foreach tab in array array['card_purchases','installment_plans','installments'] loop execute format('create policy owner_select on public.%I for select to authenticated using(user_id=auth.uid() and deleted_at is null)',tab); execute format('create policy owner_insert on public.%I for insert to authenticated with check(user_id=auth.uid())',tab); execute format('create policy owner_update on public.%I for update to authenticated using(user_id=auth.uid() and deleted_at is null) with check(user_id=auth.uid())',tab); end loop; end $$;
