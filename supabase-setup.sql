begin;

-- Apply this script in the Supabase SQL Editor. Create Auth users separately,
-- then add a scholar_profiles row for each Auth user's UUID.

create table if not exists public.scholar_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  role text not null check (role in ('staff', 'scholar')),
  scholar_id text unique check (scholar_id in ('s01', 's02', 's03', 's04', 's05', 's06')),
  constraint scholar_profiles_role_id_check check (
    (role = 'staff' and scholar_id is null)
    or (role = 'scholar' and scholar_id is not null)
  )
);

create table if not exists public.scholarship_submissions (
  id text primary key,
  scholar_id text not null,
  academic_year text not null,
  semester text not null,
  gwa numeric(3, 2) not null check (gwa between 1.00 and 5.00),
  enrolled_units integer not null check (enrolled_units >= 0),
  failed_count integer not null check (failed_count >= 0),
  inc_count integer not null check (inc_count >= 0),
  drop_count integer not null check (drop_count >= 0),
  evidence_ref text not null,
  submitted_at timestamptz not null,
  verification_status text not null default 'Pending verification',
  verification_notes text not null default '',
  compliance_result text not null default 'Pending',
  compliance_reasons text[] not null default '{}',
  renewal_decision text not null default 'Pending',
  decision_notes text not null default '',
  unique (scholar_id, academic_year, semester),
  check (scholar_id in ('s01', 's02', 's03', 's04', 's05', 's06')),
  check (renewal_decision <> 'Approved' or compliance_result = 'Compliant')
);

create table if not exists public.scholarship_audit_logs (
  id text primary key,
  submission_id text not null references public.scholarship_submissions (id) on delete cascade,
  actor text not null,
  action_type text not null,
  timestamp timestamptz not null default now(),
  notes text not null default '',
  previous_state text,
  new_state text
);

create index if not exists scholarship_submissions_scholar_idx
  on public.scholarship_submissions (scholar_id);
create index if not exists scholarship_audit_logs_submission_idx
  on public.scholarship_audit_logs (submission_id);

alter table public.scholar_profiles enable row level security;
alter table public.scholarship_submissions enable row level security;
alter table public.scholarship_audit_logs enable row level security;

drop policy if exists scholar_profiles_read_self on public.scholar_profiles;
create policy scholar_profiles_read_self
  on public.scholar_profiles for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists scholarship_submissions_read_authorized on public.scholarship_submissions;
create policy scholarship_submissions_read_authorized
  on public.scholarship_submissions for select to authenticated
  using (
    exists (
      select 1 from public.scholar_profiles p
      where p.user_id = (select auth.uid())
        and (p.role = 'staff' or p.scholar_id = scholarship_submissions.scholar_id)
    )
  );

drop policy if exists scholarship_submissions_insert_authorized on public.scholarship_submissions;
create policy scholarship_submissions_insert_authorized
  on public.scholarship_submissions for insert to authenticated
  with check (
    verification_status = 'Pending verification'
    and compliance_result = 'Pending'
    and compliance_reasons = '{}'::text[]
    and renewal_decision = 'Pending'
    and verification_notes = ''
    and decision_notes = ''
    and exists (
      select 1 from public.scholar_profiles p
      where p.user_id = (select auth.uid())
        and (p.role = 'staff' or (p.role = 'scholar' and p.scholar_id = scholarship_submissions.scholar_id))
    )
  );

drop policy if exists scholarship_submissions_update_authorized on public.scholarship_submissions;
create policy scholarship_submissions_update_authorized
  on public.scholarship_submissions for update to authenticated
  using (
    exists (
      select 1 from public.scholar_profiles p
      where p.user_id = (select auth.uid())
        and (
          p.role = 'staff'
          or (p.role = 'scholar' and p.scholar_id = scholarship_submissions.scholar_id
              and scholarship_submissions.verification_status = 'Returned')
        )
    )
  )
  with check (
    exists (
      select 1 from public.scholar_profiles p
      where p.user_id = (select auth.uid())
        and (
          p.role = 'staff'
          or (p.role = 'scholar' and p.scholar_id = scholarship_submissions.scholar_id
              and scholarship_submissions.verification_status = 'Pending verification'
              and scholarship_submissions.compliance_result = 'Pending'
              and scholarship_submissions.compliance_reasons = '{}'::text[]
              and scholarship_submissions.renewal_decision = 'Pending'
              and scholarship_submissions.verification_notes = ''
              and scholarship_submissions.decision_notes = '')
        )
    )
  );

drop policy if exists scholarship_audit_logs_read_authorized on public.scholarship_audit_logs;
create policy scholarship_audit_logs_read_authorized
  on public.scholarship_audit_logs for select to authenticated
  using (
    exists (
      select 1
      from public.scholarship_submissions s
      join public.scholar_profiles p on p.user_id = (select auth.uid())
      where s.id = scholarship_audit_logs.submission_id
        and (p.role = 'staff' or p.scholar_id = s.scholar_id)
    )
  );

drop policy if exists scholarship_audit_logs_insert_authorized on public.scholarship_audit_logs;
create policy scholarship_audit_logs_insert_authorized
  on public.scholarship_audit_logs for insert to authenticated
  with check (
    exists (
      select 1
      from public.scholarship_submissions s
      join public.scholar_profiles p on p.user_id = (select auth.uid())
      where s.id = scholarship_audit_logs.submission_id
        and (
          (p.role = 'staff' and scholarship_audit_logs.actor = 'Scholarship Staff')
          or (p.role = 'scholar' and p.scholar_id = s.scholar_id
              and scholarship_audit_logs.actor = 'Scholar')
        )
    )
  );

grant select on public.scholar_profiles to authenticated;
grant select, insert, update on public.scholarship_submissions to authenticated;
grant select, insert on public.scholarship_audit_logs to authenticated;

insert into public.scholarship_submissions (
  id, scholar_id, academic_year, semester, gwa, enrolled_units, failed_count, inc_count, drop_count,
  evidence_ref, submitted_at, verification_status, verification_notes, compliance_result,
  compliance_reasons, renewal_decision, decision_notes
) values
  ('sub_a01', 's01', '2026-2027', 'Semester 1', 1.75, 18, 0, 0, 0, 'https://docs.univ.edu/grades/A01.pdf', '2026-10-30T17:00:00+08:00', 'Verified', 'Document matches official seal.', 'Pending', '{}', 'Pending', ''),
  ('sub_a02', 's02', '2026-2027', 'Semester 1', 1.76, 18, 0, 0, 0, 'https://docs.univ.edu/grades/A02.pdf', '2026-10-29T10:00:00+08:00', 'Verified', 'Evidence clear.', 'Pending', '{}', 'Pending', ''),
  ('sub_a03', 's03', '2026-2027', 'Semester 1', 2.25, 15, 0, 0, 1, 'https://docs.univ.edu/grades/A03.pdf', '2026-10-29T14:30:00+08:00', 'Verified', 'Verified.', 'Pending', '{}', 'Pending', ''),
  ('sub_a04', 's04', '2026-2027', 'Semester 1', 2.25, 14, 0, 1, 0, 'https://docs.univ.edu/grades/A04.pdf', '2026-10-29T09:15:00+08:00', 'Verified', 'Verified.', 'Pending', '{}', 'Pending', ''),
  ('sub_a05', 's05', '2026-2027', 'Semester 1', 1.50, 18, 1, 0, 0, 'https://docs.univ.edu/grades/A05.pdf', '2026-10-30T17:01:00+08:00', 'Verified', 'Verified late timestamp.', 'Pending', '{}', 'Pending', ''),
  ('sub_a06', 's06', '2026-2027', 'Semester 1', 2.00, 15, 0, 0, 0, 'https://docs.univ.edu/grades/A06.pdf', '2026-10-29T11:00:00+08:00', 'Pending verification', '', 'Pending', '{}', 'Pending', '')
on conflict (id) do nothing;

commit;
