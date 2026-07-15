create table public.notifications (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict, notification_type text not null, title text not null, body text not null, data jsonb not null default '{}'::jsonb, read_at timestamptz,
 created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz
);
create trigger notifications_set_updated_at before update on public.notifications for each row execute function public.set_updated_at();
create table public.settings (
 id uuid primary key default gen_random_uuid(), user_id uuid not null unique references auth.users(id) on delete restrict, value jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz
);
create trigger settings_set_updated_at before update on public.settings for each row execute function public.set_updated_at();
create table public.audit_logs (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete restrict, actor_id uuid, action text not null, entity_type text not null, entity_id uuid not null, before_data jsonb, after_data jsonb,
 created_at timestamptz not null default timezone('utc',now()), updated_at timestamptz not null default timezone('utc',now()), deleted_at timestamptz
);
create trigger audit_logs_set_updated_at before update on public.audit_logs for each row execute function public.set_updated_at();
