alter type public.ai_action_status add value if not exists 'parsed';
alter type public.ai_action_status add value if not exists 'validated';
alter type public.ai_action_status add value if not exists 'executing';
alter type public.ai_action_status add value if not exists 'success';
alter type public.ai_action_status add value if not exists 'cancelled';

alter table public.chat_messages add column status text not null default 'success' check(status in ('sending','sent','processing','success','failure')), add column structured_data jsonb;
alter table public.ai_actions add column message_id uuid references public.chat_messages(id) on delete restrict, add column validated_payload jsonb, add column entity_type text, add column entity_id uuid, add column confidence numeric(4,3) check(confidence between 0 and 1), add column error_message text;
create index ai_actions_message_idx on public.ai_actions(message_id) where deleted_at is null;

create table public.conversation_contexts (
 id uuid primary key default gen_random_uuid(), user_id uuid not null unique references auth.users(id) on delete restrict, chat_session_id uuid references public.chat_sessions(id) on delete restrict,
 last_intent text, last_action_id uuid references public.ai_actions(id) on delete set null, last_entity_type text, last_entity_id uuid, recent_references jsonb not null default '[]'::jsonb,
 created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz
);
create trigger conversation_contexts_set_updated_at before update on public.conversation_contexts for each row execute function public.set_updated_at();
alter table public.conversation_contexts enable row level security;
create policy conversation_contexts_select on public.conversation_contexts for select to authenticated using(user_id=auth.uid() and deleted_at is null);
create policy conversation_contexts_insert on public.conversation_contexts for insert to authenticated with check(user_id=auth.uid());
create policy conversation_contexts_update on public.conversation_contexts for update to authenticated using(user_id=auth.uid() and deleted_at is null) with check(user_id=auth.uid());
