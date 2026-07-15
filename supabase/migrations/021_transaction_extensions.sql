alter table public.transactions
 add column notes text,
 add column original_transaction_id uuid references public.transactions(id) on delete restrict,
 add column recurrence_rule text,
 add column next_execution_at timestamptz,
 add column installment_group_id uuid,
 add column installment_number smallint,
 add column installment_total smallint,
 add constraint transactions_no_self_refund check (original_transaction_id is null or original_transaction_id <> id),
 add constraint transactions_installment_valid check ((installment_number is null and installment_total is null) or (installment_number between 1 and installment_total));

create index transactions_original_transaction_idx on public.transactions(original_transaction_id) where deleted_at is null;
create index transactions_cursor_idx on public.transactions(user_id, occurred_at desc, id desc) where deleted_at is null;
