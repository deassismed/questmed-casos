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

update public.fmd_attempts
set
  weighted_elapsed_seconds = least(480, greatest(0, elapsed_seconds)),
  score_clock_updated_at = coalesce(started_at, updated_at),
  completion_reason = case
    when state = 'completed' and is_correct is true then 'correct'
    when state = 'completed' and is_correct is false then 'timeout'
    else completion_reason
  end
where
  weighted_elapsed_seconds = 0
  or score_clock_updated_at is null
  or (state = 'completed' and completion_reason is null);

alter table public.fmd_groups
  drop constraint if exists fmd_groups_status_check;

alter table public.fmd_groups
  add constraint fmd_groups_status_check
  check (status in (
    'waiting_case',
    'ready',
    'playing',
    'term_penalty',
    'discussion_pause',
    'finished_case',
    'room_finished'
  ));

alter table public.fmd_attempts
  drop constraint if exists fmd_attempts_state_check;

alter table public.fmd_attempts
  add constraint fmd_attempts_state_check
  check (state in (
    'ready',
    'playing',
    'term_penalty',
    'discussion_pause',
    'completed',
    'interrupted'
  ));

drop index if exists public.fmd_one_active_attempt_per_group;

create unique index fmd_one_active_attempt_per_group
  on public.fmd_attempts(group_id)
  where state in ('ready', 'playing', 'term_penalty', 'discussion_pause');

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
    where room_id = target_room_id
      and state in ('ready', 'playing', 'term_penalty', 'discussion_pause');

  update public.fmd_groups
    set status = 'room_finished', last_activity_at = now()
    where room_id = target_room_id;
end;
$$;

revoke all on function public.fmd_finish_room(uuid) from public;
revoke all on function public.fmd_finish_room(uuid) from anon;
revoke all on function public.fmd_finish_room(uuid) from authenticated;
grant execute on function public.fmd_finish_room(uuid) to service_role;
