-- CONFLUX V3 workspace route helpers
--
-- These functions support real-data route surfaces without exposing protected
-- profile or project information through client-side joins.

create or replace function public.cf_list_my_blocks()
returns table (
  blocked_id uuid,
  username text,
  full_name text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public, auth
as $$
  select b.blocked_id, p.username, p.full_name, b.created_at
  from public.cf_blocks b
  join public.cf_profiles p on p.id = b.blocked_id
  where b.blocker_id = auth.uid()
  order by b.created_at desc;
$$;

revoke all on function public.cf_list_my_blocks() from public;
grant execute on function public.cf_list_my_blocks() to authenticated;

-- Project discussion uses a client-generated idempotency key, just like
-- persistent mutual chat. A retry therefore cannot duplicate a message.
alter table public.cf_project_messages
  add column if not exists client_message_id uuid;

create unique index if not exists cf_project_messages_client_message_unique_idx
  on public.cf_project_messages (client_message_id)
  where client_message_id is not null;

create or replace function public.cf_send_project_message(
  requested_project_id uuid,
  requested_body text,
  requested_client_message_id uuid
)
returns public.cf_project_messages
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  actor uuid := auth.uid();
  existing public.cf_project_messages;
  inserted public.cf_project_messages;
begin
  if actor is null then raise exception 'UNAUTHENTICATED'; end if;
  if requested_client_message_id is null then raise exception 'CLIENT_MESSAGE_ID_REQUIRED'; end if;
  if char_length(trim(coalesce(requested_body, ''))) not between 1 and 4000 then
    raise exception 'VALIDATION_ERROR';
  end if;
  if not public.cf_is_project_member(requested_project_id, actor) then
    raise exception 'ROOM_ACCESS_REQUIRED';
  end if;

  select * into existing
  from public.cf_project_messages
  where client_message_id = requested_client_message_id;

  if found then
    if existing.project_id <> requested_project_id or existing.sender_id <> actor then
      raise exception 'IDEMPOTENCY_KEY_CONFLICT';
    end if;
    return existing;
  end if;

  insert into public.cf_project_messages (project_id, sender_id, body, client_message_id)
  values (requested_project_id, actor, trim(requested_body), requested_client_message_id)
  returning * into inserted;

  insert into public.cf_project_activity (project_id, actor_id, event_type, payload)
  values (requested_project_id, actor, 'PROJECT_MESSAGE_SENT', jsonb_build_object('message_id', inserted.id));

  return inserted;
end;
$$;

drop policy if exists "project messages members send" on public.cf_project_messages;
drop policy if exists "project messages direct browser insert disabled" on public.cf_project_messages;
create policy "project messages direct browser insert disabled"
  on public.cf_project_messages for insert to authenticated with check (false);

revoke all on function public.cf_send_project_message(uuid, text, uuid) from public;
grant execute on function public.cf_send_project_message(uuid, text, uuid) to authenticated;

do $$ begin
  alter publication supabase_realtime add table public.cf_project_messages;
exception when duplicate_object or undefined_object then null;
end $$;
