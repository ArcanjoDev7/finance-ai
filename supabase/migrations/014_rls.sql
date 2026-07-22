alter table public.profiles enable row level security;
alter table public.wallets enable row level security;
alter table public.accounts enable row level security;
alter table public.categories enable row level security;
alter table public.transactions enable row level security;
alter table public.transaction_attachments enable row level security;
alter table public.cards enable row level security;
alter table public.card_invoices enable row level security;
alter table public.card_transactions enable row level security;
alter table public.investments enable row level security;
alter table public.crypto_transactions enable row level security;
alter table public.goals enable row level security;
alter table public.budgets enable row level security;
alter table public.monthly_reports enable row level security;
alter table public.notifications enable row level security;
alter table public.chat_sessions enable row level security;
alter table public.chat_messages enable row level security;
alter table public.ai_actions enable row level security;
alter table public.settings enable row level security;
alter table public.audit_logs enable row level security;

do $$
declare tab text;
begin
 foreach tab in array array['profiles','wallets','accounts','categories','transactions','transaction_attachments','cards','card_invoices','card_transactions','investments','crypto_transactions','goals','budgets','monthly_reports','notifications','chat_sessions','chat_messages','ai_actions','settings'] loop
   execute format('create policy owner_select on public.%I for select to authenticated using (user_id = auth.uid() and deleted_at is null)',tab);
   execute format('create policy owner_insert on public.%I for insert to authenticated with check (user_id = auth.uid())',tab);
   execute format('create policy owner_update on public.%I for update to authenticated using (user_id = auth.uid() and deleted_at is null) with check (user_id = auth.uid())',tab);
 end loop;
end $$;
create policy audit_owner_select on public.audit_logs for select to authenticated using (user_id = auth.uid() and deleted_at is null);

alter table public.category_templates enable row level security;
alter table public.investment_types enable row level security;
alter table public.crypto_assets enable row level security;
create policy category_templates_read on public.category_templates for select to authenticated using (true);
create policy investment_types_read on public.investment_types for select to authenticated using (deleted_at is null);
create policy crypto_assets_read on public.crypto_assets for select to authenticated using (deleted_at is null);
