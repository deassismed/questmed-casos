alter table public.fmd_attempts
  add column if not exists weighted_elapsed_seconds numeric(8,3) not null default 0;

alter table public.fmd_attempts
  add column if not exists score_clock_updated_at timestamptz;

alter table public.fmd_attempts
  add column if not exists completion_reason text;

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
