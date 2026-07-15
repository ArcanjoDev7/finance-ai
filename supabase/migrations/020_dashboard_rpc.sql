create or replace function public.dashboard_snapshot(p_from timestamptz, p_to timestamptz)
returns jsonb language sql stable security invoker set search_path = public as $$
 with me as (select auth.uid() user_id), tx as (
  select t.* from public.transactions t join me on me.user_id=t.user_id
  where t.deleted_at is null and t.status='paid' and t.occurred_at >= p_from and t.occurred_at < p_to
 ), totals as (
  select coalesce(sum(amount_minor) filter(where transaction_type in ('income','refund','crypto_sell')),0) income_minor,
         coalesce(sum(amount_minor) filter(where transaction_type='expense'),0) expense_minor,
         coalesce(sum(amount_minor) filter(where transaction_type in ('investment','crypto_buy')),0) invested_minor from tx
 )
 select jsonb_build_object(
  'balance_minor',coalesce((select sum(current_balance_minor) from public.accounts a join me on a.user_id=me.user_id where a.deleted_at is null),0),
  'net_worth_minor',coalesce((select public.calculate_net_worth(user_id) from me),0),
  'income_minor',(select income_minor from totals),'expense_minor',(select expense_minor from totals),'invested_minor',(select invested_minor from totals),
  'recent_transactions',coalesce((select jsonb_agg(jsonb_build_object('id',id,'description',description,'amount_minor',amount_minor,'type',transaction_type,'occurred_at',occurred_at) order by occurred_at desc) from (select * from tx order by occurred_at desc limit 10) recent),'[]'::jsonb)
 );
$$;
revoke all on function public.dashboard_snapshot(timestamptz,timestamptz) from public;
grant execute on function public.dashboard_snapshot(timestamptz,timestamptz) to authenticated;
