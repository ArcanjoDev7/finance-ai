create or replace function public.calculate_balance(p_account_id uuid)
returns bigint language sql stable security invoker set search_path = public as $$
 select a.opening_balance_minor + coalesce(sum(
  case when t.account_id = p_account_id then case t.transaction_type
    when 'income' then t.amount_minor when 'refund' then t.amount_minor when 'crypto_sell' then t.amount_minor
    when 'expense' then -t.amount_minor when 'investment' then -t.amount_minor when 'crypto_buy' then -t.amount_minor when 'transfer' then -t.amount_minor else 0 end
  when t.destination_account_id = p_account_id and t.transaction_type = 'transfer' then t.amount_minor else 0 end),0)
 from public.accounts a left join public.transactions t on (t.account_id=a.id or t.destination_account_id=a.id) and t.status='paid' and t.deleted_at is null
 where a.id=p_account_id and a.deleted_at is null group by a.opening_balance_minor;
$$;

create or replace function public.calculate_net_worth(p_user_id uuid)
returns bigint language sql stable security invoker set search_path = public as $$
 select coalesce((select sum(current_balance_minor) from public.accounts where user_id=p_user_id and deleted_at is null),0)
      + coalesce((select sum(current_amount_minor) from public.investments where user_id=p_user_id and deleted_at is null),0);
$$;

create or replace function public.monthly_summary(p_user_id uuid,p_month date)
returns table(income_minor bigint,expense_minor bigint,investment_minor bigint,net_minor bigint) language sql stable security invoker set search_path = public as $$
 select coalesce(sum(amount_minor) filter(where transaction_type in ('income','refund','crypto_sell')),0),
 coalesce(sum(amount_minor) filter(where transaction_type='expense'),0), coalesce(sum(amount_minor) filter(where transaction_type in ('investment','crypto_buy')),0),
 coalesce(sum(case when transaction_type in ('income','refund','crypto_sell') then amount_minor when transaction_type in ('expense','investment','crypto_buy') then -amount_minor else 0 end),0)
 from public.transactions where user_id=p_user_id and status='paid' and deleted_at is null and occurred_at >= date_trunc('month',p_month) and occurred_at < date_trunc('month',p_month)+interval '1 month';
$$;
create or replace function public.year_summary(p_user_id uuid,p_year int)
returns table(income_minor bigint,expense_minor bigint,investment_minor bigint,net_minor bigint) language sql stable security invoker set search_path = public as $$
 select coalesce(sum(amount_minor) filter(where transaction_type in ('income','refund','crypto_sell')),0),
 coalesce(sum(amount_minor) filter(where transaction_type='expense'),0), coalesce(sum(amount_minor) filter(where transaction_type in ('investment','crypto_buy')),0),
 coalesce(sum(case when transaction_type in ('income','refund','crypto_sell') then amount_minor when transaction_type in ('expense','investment','crypto_buy') then -amount_minor else 0 end),0)
 from public.transactions where user_id=p_user_id and status='paid' and deleted_at is null and occurred_at >= make_date(p_year,1,1) and occurred_at < make_date(p_year+1,1,1);
$$;
create or replace function public.goal_progress(p_goal_id uuid)
returns numeric language sql stable security invoker set search_path = public as $$
 select case when target_amount_minor=0 then 0 else current_amount_minor::numeric/target_amount_minor end from public.goals where id=p_goal_id and deleted_at is null;
$$;

create or replace view public.current_balances with (security_invoker=true) as select id as account_id,user_id,wallet_id,name,currency_code,current_balance_minor from public.accounts where deleted_at is null;
create or replace view public.net_worth with (security_invoker=true) as select p.user_id,public.calculate_net_worth(p.user_id) as net_worth_minor,p.default_currency as currency_code from public.profiles p where p.deleted_at is null;
create or replace view public.monthly_summary_view with (security_invoker=true) as select user_id,date_trunc('month',occurred_at)::date as reference_month,currency_code,coalesce(sum(amount_minor) filter(where transaction_type in ('income','refund','crypto_sell')),0) income_minor,coalesce(sum(amount_minor) filter(where transaction_type='expense'),0) expense_minor,coalesce(sum(amount_minor) filter(where transaction_type in ('investment','crypto_buy')),0) investment_minor from public.transactions where status='paid' and deleted_at is null group by user_id,date_trunc('month',occurred_at)::date,currency_code;
create or replace view public.annual_summary_view with (security_invoker=true) as select user_id,date_part('year',reference_month)::int as reference_year,currency_code,sum(income_minor) income_minor,sum(expense_minor) expense_minor,sum(investment_minor) investment_minor from public.monthly_summary_view group by user_id,date_part('year',reference_month)::int,currency_code;
create or replace view public.investment_portfolio with (security_invoker=true) as select i.*,it.code as investment_type_code,it.name as investment_type_name,(i.current_amount_minor-i.invested_amount_minor) profit_loss_minor from public.investments i join public.investment_types it on it.id=i.investment_type_id where i.deleted_at is null;
create or replace view public.crypto_portfolio with (security_invoker=true) as select ct.user_id,ct.account_id,ca.symbol,ca.name,sum(case when operation_type in ('buy','staking','reward') then quantity when operation_type='sell' then -quantity else 0 end) quantity from public.crypto_transactions ct join public.crypto_assets ca on ca.id=ct.crypto_asset_id where ct.deleted_at is null group by ct.user_id,ct.account_id,ca.symbol,ca.name;
