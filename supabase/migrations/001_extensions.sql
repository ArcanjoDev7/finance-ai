create extension if not exists pgcrypto;

create type public.transaction_type as enum ('income','expense','transfer','investment','crypto_buy','crypto_sell','refund');
create type public.transaction_status as enum ('pending','paid','cancelled','scheduled');
create type public.payment_method as enum ('pix','cash','credit_card','debit_card','bank_transfer','crypto');
create type public.crypto_operation_type as enum ('buy','sell','transfer','staking','reward');
create type public.goal_status as enum ('active','completed','paused','cancelled');
create type public.ai_action_status as enum ('received','processed','failed','rejected');

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = public as $$
begin new.updated_at = timezone('utc', now()); return new; end;
$$;

create or replace function public.is_current_user(owner_id uuid)
returns boolean language sql stable as $$ select auth.uid() = owner_id; $$;
