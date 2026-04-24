-- Content reporting table — lets users flag abusive / spam / illegal content
-- so we satisfy Play Store content-policy requirements. v1: capture + store only;
-- moderation is manual SQL review by the admin team until a proper queue UI ships.

create table if not exists public.content_reports (
    id uuid primary key default gen_random_uuid(),
    reporter_user_id uuid not null references auth.users(id) on delete cascade,
    target_type text not null,
    target_id text not null,
    reason text not null,
    notes text,
    status text not null default 'pending',
    created_at timestamptz not null default now(),
    reviewed_at timestamptz,
    reviewed_by uuid references auth.users(id) on delete set null,

    constraint content_reports_target_type_check
        check (target_type in ('chat_message', 'part_listing', 'repair_job', 'rfq', 'profile')),
    constraint content_reports_reason_check
        check (reason in ('spam', 'abuse', 'scam', 'illegal', 'harassment', 'inappropriate', 'other')),
    constraint content_reports_status_check
        check (status in ('pending', 'reviewed', 'actioned', 'dismissed')),
    constraint content_reports_notes_len check (notes is null or char_length(notes) <= 1000)
);

create index if not exists content_reports_reporter_idx
    on public.content_reports (reporter_user_id);
create index if not exists content_reports_target_idx
    on public.content_reports (target_type, target_id);
create index if not exists content_reports_pending_idx
    on public.content_reports (created_at desc) where status = 'pending';

alter table public.content_reports enable row level security;

-- Authenticated users can only insert reports they themselves authored.
-- The reporter_user_id is server-pinned via WITH CHECK so the client can't
-- attribute a report to someone else.
create policy content_reports_insert_own
    on public.content_reports
    for insert
    to authenticated
    with check (reporter_user_id = auth.uid());

-- Users can read their own reports (to show history / dedupe on the client).
-- Admin read access is granted out-of-band via a service-role query.
create policy content_reports_select_own
    on public.content_reports
    for select
    to authenticated
    using (reporter_user_id = auth.uid());

-- Deliberately no UPDATE or DELETE policy — once submitted, a report is
-- immutable from the client. Admin team mutates via service-role.

comment on table public.content_reports is
    'User-submitted abuse / spam / content-policy reports. RLS allows insert-own + select-own; admin handles mutation via service-role.';
