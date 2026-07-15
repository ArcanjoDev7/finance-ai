create type public.investment_event_type as enum ('contribution','redemption','income','interest','dividend','fee','tax','adjustment');
create type public.investment_status as enum ('active','matured','redeemed','cancelled');
create type public.profitability_type as enum ('post_fixed','pre_fixed','hybrid');
create type public.liquidity_type as enum ('daily','at_maturity','custom');
create type public.benchmark_type as enum ('cdi','selic','ipca','fixed','other');

alter table public.investments
 add column issuer_name text,
 add column ticker text,
 add column status public.investment_status not null default 'active',
 add column purchase_on date,
 add column liquidity_type public.liquidity_type,
 add column liquidity_days integer check(liquidity_days >= 0),
 add column profitability_type public.profitability_type,
 add column profitability_rate numeric(12,6),
 add column benchmark_type public.benchmark_type,
 add column benchmark_percentage numeric(12,6),
 add column fixed_rate numeric(12,6),
 add column inflation_rate numeric(12,6),
 add column notes text;

create table public.investment_events (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict,
 investment_id uuid not null references public.investments(id) on delete restrict, transaction_id uuid unique references public.transactions(id) on delete restrict,
 event_type public.investment_event_type not null, amount_minor bigint not null check(amount_minor > 0), quantity numeric(30,12), unit_price_minor bigint check(unit_price_minor >= 0), description text,
 occurred_at timestamptz not null, created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz
);
create trigger investment_events_set_updated_at before update on public.investment_events for each row execute function public.set_updated_at();
create index investment_events_user_occurred_idx on public.investment_events(user_id,occurred_at desc) where deleted_at is null;

create table public.benchmark_rates (
 id uuid primary key default gen_random_uuid(), benchmark_type public.benchmark_type not null, rate numeric(12,6) not null, reference_on date not null, source text not null,
 created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz, unique(benchmark_type,reference_on,source)
);
create trigger benchmark_rates_set_updated_at before update on public.benchmark_rates for each row execute function public.set_updated_at();

alter table public.investment_events enable row level security;
create policy investment_events_select on public.investment_events for select to authenticated using(user_id=auth.uid() and deleted_at is null);
create policy investment_events_insert on public.investment_events for insert to authenticated with check(user_id=auth.uid());
create policy investment_events_update on public.investment_events for update to authenticated using(user_id=auth.uid() and deleted_at is null) with check(user_id=auth.uid());
alter table public.benchmark_rates enable row level security;
create policy benchmark_rates_select on public.benchmark_rates for select to authenticated using(deleted_at is null);
