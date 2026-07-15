create or replace function public.assert_transaction_ownership()
returns trigger language plpgsql security definer set search_path = public as $$
begin
 if not exists(select 1 from public.wallets where id=new.wallet_id and user_id=new.user_id and deleted_at is null) then raise exception 'wallet does not belong to user'; end if;
 if new.account_id is not null and not exists(select 1 from public.accounts where id=new.account_id and user_id=new.user_id and deleted_at is null) then raise exception 'account does not belong to user'; end if;
 if new.destination_account_id is not null and not exists(select 1 from public.accounts where id=new.destination_account_id and user_id=new.user_id and deleted_at is null) then raise exception 'destination account does not belong to user'; end if;
 if new.category_id is not null and not exists(select 1 from public.categories where id=new.category_id and user_id=new.user_id and deleted_at is null) then raise exception 'category does not belong to user'; end if;
 return new;
end; $$;
create trigger transactions_assert_ownership before insert or update on public.transactions for each row execute function public.assert_transaction_ownership();

create or replace function public.refresh_transaction_projections()
returns trigger language plpgsql security definer set search_path = public as $$
declare r record; affected_user uuid := coalesce(new.user_id,old.user_id); affected_month date := date_trunc('month',coalesce(new.occurred_at,old.occurred_at))::date; affected_currency char(3) := coalesce(new.currency_code,old.currency_code);
begin
 for r in select distinct id from public.accounts where id in (old.account_id,old.destination_account_id,new.account_id,new.destination_account_id) loop
   update public.accounts set current_balance_minor=coalesce(public.calculate_balance(r.id),0) where id=r.id;
 end loop;
 update public.budgets b set used_amount_minor=coalesce((select sum(t.amount_minor) from public.transactions t where t.user_id=b.user_id and t.category_id=b.category_id and t.transaction_type='expense' and t.status='paid' and t.deleted_at is null and t.occurred_at >= b.reference_month and t.occurred_at < b.reference_month+interval '1 month'),0) where b.user_id=affected_user and b.reference_month=affected_month;
 insert into public.monthly_reports(user_id,reference_month,currency_code,income_minor,expense_minor,investment_minor,profit_minor,net_worth_minor,calculated_at)
 select affected_user,affected_month,affected_currency,s.income_minor,s.expense_minor,s.investment_minor,s.net_minor,public.calculate_net_worth(affected_user),timezone('utc',now()) from public.monthly_summary(affected_user,affected_month) s
 on conflict(user_id,reference_month,currency_code) do update set income_minor=excluded.income_minor,expense_minor=excluded.expense_minor,investment_minor=excluded.investment_minor,profit_minor=excluded.profit_minor,net_worth_minor=excluded.net_worth_minor,calculated_at=excluded.calculated_at;
 if tg_op = 'DELETE' then return old; end if;
 return new;
end; $$;
create trigger transactions_refresh_projections after insert or update or delete on public.transactions for each row execute function public.refresh_transaction_projections();

create or replace function public.write_audit_log()
returns trigger language plpgsql security definer set search_path = public as $$
declare owner_id uuid; entity_id uuid; before_json jsonb; after_json jsonb;
begin
 if tg_op='DELETE' then owner_id:=old.user_id; entity_id:=old.id; before_json:=to_jsonb(old); else owner_id:=new.user_id; entity_id:=new.id; after_json:=to_jsonb(new); if tg_op='UPDATE' then before_json:=to_jsonb(old); end if; end if;
 insert into public.audit_logs(user_id,actor_id,action,entity_type,entity_id,before_data,after_data) values(owner_id,auth.uid(),lower(tg_op),tg_table_name,entity_id,before_json,after_json);
 if tg_op = 'DELETE' then return old; end if;
 return new;
end; $$;
create trigger transactions_audit after insert or update or delete on public.transactions for each row execute function public.write_audit_log();
create trigger accounts_audit after insert or update or delete on public.accounts for each row execute function public.write_audit_log();
create trigger cards_audit after insert or update or delete on public.cards for each row execute function public.write_audit_log();
create trigger investments_audit after insert or update or delete on public.investments for each row execute function public.write_audit_log();
