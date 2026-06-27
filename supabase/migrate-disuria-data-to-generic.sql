do $$
begin
  if to_regclass('public.fmd_rooms') is null then
    raise exception 'Tabela public.fmd_rooms não existe. Execute supabase/schema.sql antes desta migração.';
  end if;
  if to_regclass('public.fmd_groups') is null then
    raise exception 'Tabela public.fmd_groups não existe. Execute supabase/schema.sql antes desta migração.';
  end if;
  if to_regclass('public.fmd_attempts') is null then
    raise exception 'Tabela public.fmd_attempts não existe. Execute supabase/schema.sql antes desta migração.';
  end if;
  if to_regclass('public.fmd_room_admin') is null then
    raise exception 'Tabela public.fmd_room_admin não existe. Execute supabase/schema.sql antes desta migração.';
  end if;
end $$;

do $$
begin
  if to_regclass('public.fmd_disuria_rooms') is not null then
    insert into public.fmd_rooms (
      id,
      room_code,
      room_name,
      released_case_ids,
      status,
      created_at,
      updated_at,
      finished_at
    )
    select
      id,
      room_code,
      room_name,
      released_case_ids,
      status,
      created_at,
      updated_at,
      finished_at
    from public.fmd_disuria_rooms
    on conflict (id) do update set
      room_code = excluded.room_code,
      room_name = excluded.room_name,
      released_case_ids = excluded.released_case_ids,
      status = excluded.status,
      created_at = excluded.created_at,
      updated_at = excluded.updated_at,
      finished_at = excluded.finished_at;

    raise notice 'Salas antigas copiadas para public.fmd_rooms.';
  else
    raise notice 'Tabela antiga public.fmd_disuria_rooms não encontrada; nada a copiar.';
  end if;
end $$;

do $$
begin
  if to_regclass('public.fmd_disuria_room_admin') is not null then
    insert into public.fmd_room_admin (
      room_id,
      admin_key_hash,
      created_at
    )
    select
      room_id,
      admin_key_hash,
      created_at
    from public.fmd_disuria_room_admin
    on conflict (room_id) do update set
      admin_key_hash = excluded.admin_key_hash,
      created_at = excluded.created_at;

    raise notice 'Chaves administrativas antigas copiadas para public.fmd_room_admin.';
  else
    raise notice 'Tabela antiga public.fmd_disuria_room_admin não encontrada; nada a copiar.';
  end if;
end $$;

do $$
begin
  if to_regclass('public.fmd_disuria_groups') is not null then
    insert into public.fmd_groups (
      id,
      room_id,
      nickname,
      nickname_normalized,
      status,
      current_case_id,
      completed_cases,
      total_score,
      joined_at,
      last_activity_at
    )
    select
      id,
      room_id,
      nickname,
      nickname_normalized,
      status,
      current_case_id,
      completed_cases,
      total_score,
      joined_at,
      last_activity_at
    from public.fmd_disuria_groups
    on conflict (id) do update set
      room_id = excluded.room_id,
      nickname = excluded.nickname,
      nickname_normalized = excluded.nickname_normalized,
      status = excluded.status,
      current_case_id = excluded.current_case_id,
      completed_cases = excluded.completed_cases,
      total_score = excluded.total_score,
      joined_at = excluded.joined_at,
      last_activity_at = excluded.last_activity_at;

    raise notice 'Grupos antigos copiados para public.fmd_groups.';
  else
    raise notice 'Tabela antiga public.fmd_disuria_groups não encontrada; nada a copiar.';
  end if;
end $$;

do $$
begin
  if to_regclass('public.fmd_disuria_attempts') is not null then
    insert into public.fmd_attempts (
      id,
      room_id,
      group_id,
      case_id,
      state,
      started_at,
      finished_at,
      updated_at,
      score,
      elapsed_seconds,
      weighted_elapsed_seconds,
      score_clock_updated_at,
      discussion_pause_used,
      discussion_pause_started_at,
      revealed_hint_ids,
      blocked_option_ids,
      option_order,
      selected_option_id,
      penalty_term_id,
      term_guesses,
      is_correct,
      completion_reason
    )
    select
      id,
      room_id,
      group_id,
      case_id,
      state,
      started_at,
      finished_at,
      updated_at,
      score,
      elapsed_seconds,
      weighted_elapsed_seconds,
      score_clock_updated_at,
      discussion_pause_used,
      discussion_pause_started_at,
      revealed_hint_ids,
      blocked_option_ids,
      option_order,
      selected_option_id,
      penalty_term_id,
      term_guesses,
      is_correct,
      completion_reason
    from public.fmd_disuria_attempts
    on conflict (id) do update set
      room_id = excluded.room_id,
      group_id = excluded.group_id,
      case_id = excluded.case_id,
      state = excluded.state,
      started_at = excluded.started_at,
      finished_at = excluded.finished_at,
      updated_at = excluded.updated_at,
      score = excluded.score,
      elapsed_seconds = excluded.elapsed_seconds,
      weighted_elapsed_seconds = excluded.weighted_elapsed_seconds,
      score_clock_updated_at = excluded.score_clock_updated_at,
      discussion_pause_used = excluded.discussion_pause_used,
      discussion_pause_started_at = excluded.discussion_pause_started_at,
      revealed_hint_ids = excluded.revealed_hint_ids,
      blocked_option_ids = excluded.blocked_option_ids,
      option_order = excluded.option_order,
      selected_option_id = excluded.selected_option_id,
      penalty_term_id = excluded.penalty_term_id,
      term_guesses = excluded.term_guesses,
      is_correct = excluded.is_correct,
      completion_reason = excluded.completion_reason;

    raise notice 'Tentativas antigas copiadas para public.fmd_attempts.';
  else
    raise notice 'Tabela antiga public.fmd_disuria_attempts não encontrada; nada a copiar.';
  end if;
end $$;

select
  (select count(*) from public.fmd_rooms) as salas_novas,
  (select count(*) from public.fmd_room_admin) as admins_novos,
  (select count(*) from public.fmd_groups) as grupos_novos,
  (select count(*) from public.fmd_attempts) as tentativas_novas;
