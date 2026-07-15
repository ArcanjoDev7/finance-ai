create table public.chat_sessions (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict, title text, last_message_at timestamptz,
 created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz
);
create trigger chat_sessions_set_updated_at before update on public.chat_sessions for each row execute function public.set_updated_at();
create table public.chat_messages (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict, chat_session_id uuid not null references public.chat_sessions(id) on delete restrict,
 role text not null check(role in ('user','assistant','system')), content jsonb not null, model_name text, input_tokens integer check(input_tokens >= 0), output_tokens integer check(output_tokens >= 0), latency_ms integer check(latency_ms >= 0),
 created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz
);
create trigger chat_messages_set_updated_at before update on public.chat_messages for each row execute function public.set_updated_at();
create table public.ai_actions (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict, chat_session_id uuid references public.chat_sessions(id) on delete restrict,
 intent text not null, input_json jsonb not null, result_json jsonb, status public.ai_action_status not null default 'received', idempotency_key uuid not null,
 created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz, processed_at timestamptz, unique(user_id,idempotency_key)
);
create trigger ai_actions_set_updated_at before update on public.ai_actions for each row execute function public.set_updated_at();
