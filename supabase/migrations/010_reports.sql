create table public.monthly_reports (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict,
 reference_month date not null check(reference_month = date_trunc('month',reference_month)::date), currency_code char(3) not null default 'BRL',
 income_minor bigint not null default 0, expense_minor bigint not null default 0, investment_minor bigint not null default 0, profit_minor bigint not null default 0, net_worth_minor bigint not null default 0, return_rate numeric(12,6),
 calculated_at timestamptz not null default timezone('utc',now()), created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz,
 unique(user_id,reference_month,currency_code)
);
create trigger monthly_reports_set_updated_at before update on public.monthly_reports for each row execute function public.set_updated_at();
