-- Run once in the Supabase SQL editor before deploying this branch.
begin;
create table public.student_matching (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references auth.users(id) on delete cascade,
  target_student_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint student_matching_no_self check (student_id <> target_student_id)
);
-- A single connection/request per pair, including reverse-direction requests.
create unique index student_matching_pair_key
  on public.student_matching
  (least(student_id, target_student_id), greatest(student_id, target_student_id));
create index student_matching_sender_status
  on public.student_matching (student_id, status);
create index student_matching_recipient_status
  on public.student_matching (target_student_id, status);

create function public.set_student_matching_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
create trigger student_matching_updated_at
before update on public.student_matching
for each row execute function public.set_student_matching_updated_at();

alter table public.student_matching enable row level security;
revoke all on public.student_matching from anon, authenticated;
grant select on public.student_matching to authenticated;
grant insert (student_id, target_student_id) on public.student_matching to authenticated;
grant update (status) on public.student_matching to authenticated;

create policy student_matching_read_participants
on public.student_matching for select to authenticated
using ((select auth.uid()) in (student_id, target_student_id));

create policy student_matching_send_request
on public.student_matching for insert to authenticated
with check ((select auth.uid()) = student_id and status = 'pending');

-- The recipient alone can accept or decline a pending request.
-- Column grants prevent changing the participants or timestamps.
create policy student_matching_respond
on public.student_matching for update to authenticated
using ((select auth.uid()) = target_student_id and status = 'pending')
with check ((select auth.uid()) = target_student_id
            and status in ('accepted', 'declined'));
commit;
