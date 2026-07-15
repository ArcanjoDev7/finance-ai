create table public.goals (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict, wallet_id uuid references public.wallets(id) on delete restrict,
 name text not null, target_amount_minor bigint not null check(target_amount_minor > 0), current_amount_minor bigint not null default 0 check(current_amount_minor >= 0), currency_code char(3) not null default 'BRL',
 deadline_on date, status public.goal_status not null default 'active', created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz
);
create trigger goals_set_updated_at before update on public.goals for each row execute function public.set_updated_at();
create table public.budgets (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict, category_id uuid not null references public.categories(id) on delete restrict,
 reference_month date not null check(reference_month = date_trunc('month',reference_month)::date), limit_amount_minor bigint not null check(limit_amount_minor > 0), used_amount_minor bigint not null default 0 check(used_amount_minor >= 0),
 created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz, unique(user_id,category_id,reference_month)
);
create trigger budgets_set_updated_at before update on public.budgets for each row execute function public.set_updated_at();
