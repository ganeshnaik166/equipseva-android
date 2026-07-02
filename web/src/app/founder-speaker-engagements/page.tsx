import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Engagement = {
  id: string;
  event_name: string;
  event_date: string;
  audience_label: string;
  audience_size: number;
  talk_title: string;
  talk_status: string;
  recording_url: string | null;
  slides_url: string | null;
  captured_at: string;
};

type Upcoming = {
  id: string;
  event_name: string;
  event_date: string;
  audience_label: string;
  audience_size: number;
  talk_title: string;
  talk_status: string;
};

type RecentFollowup = {
  id: string;
  engagement_id: string;
  event_name: string;
  action_type: string;
  taken_at: string;
  by_email: string;
  notes_md: string | null;
};

function fmtDate(s: string | null | undefined) {
  if (!s) return '—';
  try {
    return new Date(s).toLocaleDateString('en-IN', { year: 'numeric', month: 'short', day: '2-digit' });
  } catch {
    return s;
  }
}

function fmtTs(s: string | null | undefined) {
  if (!s) return '—';
  try {
    return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return s;
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [engRes, upRes, foRes] = await Promise.all([
    sb.rpc('list_engagements_r1946'),
    sb.rpc('upcoming_events_r1946'),
    sb.rpc('recent_followups_r1946'),
  ]);

  const engagements: Engagement[] = (engRes.data as Engagement[] | null) ?? [];
  const upcoming: Upcoming[] = (upRes.data as Upcoming[] | null) ?? [];
  const recent: RecentFollowup[] = (foRes.data as RecentFollowup[] | null) ?? [];

  const errs = [engRes.error, upRes.error, foRes.error].filter(Boolean) as { message: string }[];

  const engCols: Column<Engagement>[] = [
    { key: 'event_name', header: 'Event', render: (r: any) => r.event_name },
    { key: 'event_date', header: 'Date', render: (r: any) => fmtDate(r.event_date) },
    { key: 'audience_label', header: 'Audience', render: (r: any) => r.audience_label },
    { key: 'audience_size', header: 'Size', render: (r: any) => String(r.audience_size ?? 0) },
    { key: 'talk_title', header: 'Talk', render: (r: any) => r.talk_title },
    { key: 'talk_status', header: 'Status', render: (r: any) => r.talk_status },
    {
      key: 'recording_url',
      header: 'Recording',
      render: (r: any) => (r.recording_url ? <a className="underline" href={r.recording_url} target="_blank" rel="noreferrer">link</a> : '—'),
    },
    {
      key: 'slides_url',
      header: 'Slides',
      render: (r: any) => (r.slides_url ? <a className="underline" href={r.slides_url} target="_blank" rel="noreferrer">link</a> : '—'),
    },
    { key: 'captured_at', header: 'Captured', render: (r: any) => fmtTs(r.captured_at) },
  ];

  const upCols: Column<Upcoming>[] = [
    { key: 'event_date', header: 'Date', render: (r: any) => fmtDate(r.event_date) },
    { key: 'event_name', header: 'Event', render: (r: any) => r.event_name },
    { key: 'audience_label', header: 'Audience', render: (r: any) => r.audience_label },
    { key: 'audience_size', header: 'Size', render: (r: any) => String(r.audience_size ?? 0) },
    { key: 'talk_title', header: 'Talk', render: (r: any) => r.talk_title },
    { key: 'talk_status', header: 'Status', render: (r: any) => r.talk_status },
  ];

  const foCols: Column<RecentFollowup>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => fmtTs(r.taken_at) },
    { key: 'event_name', header: 'Event', render: (r: any) => r.event_name },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '—' },
  ];

  const totalEng = engagements.length;
  const delivered = engagements.filter((e) => e.talk_status === 'delivered').length;
  const accepted = engagements.filter((e) => e.talk_status === 'accepted').length;
  const declined = engagements.filter((e) => e.talk_status === 'declined').length;
  const totalAudience = engagements
    .filter((e) => e.talk_status === 'delivered')
    .reduce((acc, e) => acc + (e.audience_size ?? 0), 0);

  return (
    <main className="mx-auto max-w-6xl px-4 py-8 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Founder Speaker Engagements</h1>
        <p className="text-sm text-gray-600">
          Track founder talks, panels, and conference appearances. Captures status, audience reach, and follow-up actions
          (thank-you notes, recording publishing, audience re-engagement).
        </p>
      </header>

      {errs.length > 0 ? (
        <section className="rounded border border-red-300 bg-red-50 p-3 text-sm text-red-800">
          <div className="font-medium">Load errors</div>
          <ul className="list-disc ml-5">
            {errs.map((e, i) => (
              <li key={i}>{e.message}</li>
            ))}
          </ul>
        </section>
      ) : null}

      <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Total engagements</div>
          <div className="text-xl font-semibold">{totalEng}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Delivered</div>
          <div className="text-xl font-semibold">{delivered}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Accepted</div>
          <div className="text-xl font-semibold">{accepted}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Declined</div>
          <div className="text-xl font-semibold">{declined}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Audience reached</div>
          <div className="text-xl font-semibold">{totalAudience.toLocaleString('en-IN')}</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Upcoming events</h2>
        <p className="text-xs text-gray-500">Status accepted or postponed with event date on or after today.</p>
        <DataTable
          rows={upcoming}
          columns={upCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">All engagements</h2>
        <p className="text-xs text-gray-500">Most recent 200 by event date.</p>
        <DataTable
          rows={engagements}
          columns={engCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Recent follow-ups</h2>
        <p className="text-xs text-gray-500">Thank-you notes, recording publishing, audience re-engagement, content repurpose, decline follow-up.</p>
        <DataTable
          rows={recent}
          columns={foCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
