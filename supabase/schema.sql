create table if not exists public.fmd_rooms (
  id uuid primary key,
  room_code text not null unique check (room_code ~ '^[A-Z0-9]{6}$'),
  room_name text,
  released_case_ids text[] not null default '{}',
  status text not null default 'active' check (status in ('active', 'finished')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  finished_at timestamptz
);

create table if not exists public.fmd_room_admin (
  room_id uuid primary key references public.fmd_rooms(id) on delete cascade,
  admin_key_hash text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.fmd_groups (
  id uuid primary key,
  room_id uuid not null references public.fmd_rooms(id) on delete cascade,
  nickname text not null,
  nickname_normalized text not null,
  status text not null default 'waiting_case'
    check (status in ('waiting_case', 'ready', 'playing', 'term_penalty', 'discussion_pause', 'finished_case', 'room_finished')),
  current_case_id text,
  completed_cases integer not null default 0,
  total_score numeric(7,1) not null default 0,
  joined_at timestamptz not null default now(),
  last_activity_at timestamptz not null default now(),
  unique (room_id, nickname_normalized)
);

create table if not exists public.fmd_attempts (
  id uuid primary key,
  room_id uuid not null references public.fmd_rooms(id) on delete cascade,
  group_id uuid not null references public.fmd_groups(id) on delete cascade,
  case_id text not null,
  state text not null default 'ready'
    check (state in ('ready', 'playing', 'term_penalty', 'discussion_pause', 'completed', 'interrupted')),
  started_at timestamptz,
  finished_at timestamptz,
  updated_at timestamptz not null default now(),
  score numeric(5,1),
  elapsed_seconds integer not null default 0,
  weighted_elapsed_seconds numeric(8,3) not null default 0,
  score_clock_updated_at timestamptz,
  discussion_pause_used boolean not null default false,
  discussion_pause_started_at timestamptz,
  revealed_hint_ids text[] not null default '{}',
  blocked_option_ids text[] not null default '{}',
  option_order text[] not null default '{}',
  selected_option_id text,
  penalty_term_id text,
  term_guesses text[] not null default '{}',
  is_correct boolean,
  completion_reason text check (completion_reason in ('correct', 'timeout'))
);

create unique index if not exists fmd_one_active_attempt_per_group
  on public.fmd_attempts(group_id)
  where state in ('ready', 'playing', 'term_penalty', 'discussion_pause');

create index if not exists fmd_groups_room_idx on public.fmd_groups(room_id);
create index if not exists fmd_attempts_room_idx on public.fmd_attempts(room_id);
create index if not exists fmd_attempts_group_idx on public.fmd_attempts(group_id);

alter table public.fmd_rooms
  add column if not exists room_name text;

alter table public.fmd_rooms
  add column if not exists released_case_ids text[] not null default '{}';

alter table public.fmd_attempts
  add column if not exists weighted_elapsed_seconds numeric(8,3) not null default 0;

alter table public.fmd_attempts
  add column if not exists score_clock_updated_at timestamptz;

alter table public.fmd_attempts
  add column if not exists completion_reason text;

alter table public.fmd_attempts
  add column if not exists discussion_pause_used boolean not null default false;

alter table public.fmd_attempts
  add column if not exists discussion_pause_started_at timestamptz;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'fmd_attempts_completion_reason_check'
  ) then
    alter table public.fmd_attempts
      add constraint fmd_attempts_completion_reason_check
      check (completion_reason in ('correct', 'timeout'));
  end if;
end $$;

alter table public.fmd_rooms replica identity full;
alter table public.fmd_groups replica identity full;
alter table public.fmd_attempts replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'fmd_rooms'
  ) then
    alter publication supabase_realtime add table public.fmd_rooms;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'fmd_groups'
  ) then
    alter publication supabase_realtime add table public.fmd_groups;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'fmd_attempts'
  ) then
    alter publication supabase_realtime add table public.fmd_attempts;
  end if;
end $$;

alter table public.fmd_rooms enable row level security;
alter table public.fmd_room_admin enable row level security;
alter table public.fmd_groups enable row level security;
alter table public.fmd_attempts enable row level security;

revoke all on table public.fmd_room_admin from anon, authenticated;
revoke insert, update, delete on table public.fmd_rooms from anon, authenticated;
revoke insert, update, delete on table public.fmd_groups from anon, authenticated;
revoke insert, update, delete on table public.fmd_attempts from anon, authenticated;
grant select on table public.fmd_rooms to anon, authenticated;
grant select on table public.fmd_groups to anon, authenticated;
grant select on table public.fmd_attempts to anon, authenticated;

drop policy if exists "fmd public read rooms" on public.fmd_rooms;
drop policy if exists "fmd public read groups" on public.fmd_groups;
drop policy if exists "fmd public read attempts" on public.fmd_attempts;

create policy "fmd public read rooms"
  on public.fmd_rooms for select using (true);
create policy "fmd public read groups"
  on public.fmd_groups for select using (true);
create policy "fmd public read attempts"
  on public.fmd_attempts for select using (true);

create or replace function public.fmd_finish_room(target_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.fmd_rooms
    set status = 'finished', finished_at = now(), updated_at = now()
    where id = target_room_id and status <> 'finished';

  update public.fmd_attempts
    set state = 'interrupted', finished_at = now(), updated_at = now()
    where room_id = target_room_id and state in ('ready', 'playing', 'term_penalty', 'discussion_pause');

  update public.fmd_groups
    set status = 'room_finished', last_activity_at = now()
    where room_id = target_room_id;
end;
$$;

revoke all on function public.fmd_finish_room(uuid) from public;
revoke all on function public.fmd_finish_room(uuid) from anon;
revoke all on function public.fmd_finish_room(uuid) from authenticated;
grant execute on function public.fmd_finish_room(uuid) to service_role;
