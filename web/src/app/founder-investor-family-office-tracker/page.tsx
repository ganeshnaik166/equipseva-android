import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type FamilyOffice = {
  id: string;
  family_office_name: string;
  primary_contact_name: string;
  primary_contact_email: string;
  family_generation_focus: string;
  status: string;
  investment_thesis_md: string;
  meeting_count: number;
  last_meeting_date: string | null;
  created_at: string;
};

type Meeting = {
  id: string;
  family_office_id: string;
  family_office_name: string;
  meeting_date: string;
  attendee_emails: string[] | null;
  generation_attended: string;
  key_topics: string;
  follow_up_required: boolean;
  created_at: string;
};

type Summary = {
  total_count: number;
  engaged_count: number;
  cultivating_count: number;
  dormant_count: number;
  meetings_last_30d: number;
  follow_ups_pending: number;
};

type GenerationRow = {
  generation_bucket: string;
  office_count: number;
  meeting_count: number;
  engaged_offices: number;
};

function fmtDate(s: string | null): string {
  if (!s) return '—';
  try {
    return new Date(s).toLocaleDateString('en-IN', { year: 'numeric', month: 'short', day: 'numeric' });
  } catch {
    return s;
  }
}

function genLabel(g: string): string {
  if (g === 'current') return 'Current Gen';
  if (g === 'next_gen') return 'Next Gen';
  if (g === 'multi_gen') return 'Multi-Gen';
  if (g === 'both') return 'Both Gens';
  return g;
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [officesRes, meetingsRes, summaryRes, generationRes] = await Promise.all([
    sb.rpc('list_family_offices_r1765'),
    sb.rpc('list_meetings_r1765', { p_family_office_id: null }),
    sb.rpc('active_family_offices_summary_r1765'),
    sb.rpc('generation_engagement_summary_r1765'),
  ]);

  const offices: FamilyOffice[] = (officesRes.data as FamilyOffice[] | null) ?? [];
  const meetings: Meeting[] = (meetingsRes.data as Meeting[] | null) ?? [];
  const summaryRow: Summary | null =
    Array.isArray(summaryRes.data) && summaryRes.data.length > 0
      ? (summaryRes.data[0] as Summary)
      : (summaryRes.data as Summary | null);
  const generations: GenerationRow[] = (generationRes.data as GenerationRow[] | null) ?? [];

  const anyErr =
    officesRes.error?.message ||
    meetingsRes.error?.message ||
    summaryRes.error?.message ||
    generationRes.error?.message ||
    null;

  const officeColumns: Column<FamilyOffice>[] = [
    {
      key: 'name',
      header: 'Family Office',
      render: (r: FamilyOffice) => (
        <div>
          <div className="font-medium text-[var(--color-foreground)]">{r.family_office_name}</div>
          <div className="text-xs text-[var(--color-muted)]">{r.primary_contact_name}</div>
        </div>
      ),
    },
    {
      key: 'contact',
      header: 'Contact',
      render: (r: FamilyOffice) => (
        <span className="text-xs text-[var(--color-muted)]">{r.primary_contact_email}</span>
      ),
    },
    {
      key: 'generation',
      header: 'Generation Focus',
      render: (r: FamilyOffice) => (
        <span className="rounded bg-indigo-50 px-2 py-0.5 text-xs font-medium text-indigo-700">
          {genLabel(r.family_generation_focus)}
        </span>
      ),
    },
    {
      key: 'status',
      header: 'Status',
      render: (r: FamilyOffice) => {
        const cls =
          r.status === 'engaged'
            ? 'bg-green-50 text-green-700'
            : r.status === 'cultivating'
              ? 'bg-amber-50 text-amber-700'
              : 'bg-gray-100 text-gray-600';
        return <span className={`rounded px-2 py-0.5 text-xs font-medium ${cls}`}>{r.status}</span>;
      },
    },
    {
      key: 'meetings',
      header: 'Meetings',
      render: (r: FamilyOffice) => (
        <span className="text-sm tabular-nums">{Number(r.meeting_count ?? 0)}</span>
      ),
    },
    {
      key: 'last_meeting',
      header: 'Last Meeting',
      render: (r: FamilyOffice) => (
        <span className="text-xs text-[var(--color-muted)]">{fmtDate(r.last_meeting_date)}</span>
      ),
    },
    {
      key: 'created',
      header: 'Added',
      render: (r: FamilyOffice) => (
        <span className="text-xs text-[var(--color-muted)]">{fmtDate(r.created_at)}</span>
      ),
    },
  ];

  const meetingColumns: Column<Meeting>[] = [
    {
      key: 'date',
      header: 'Date',
      render: (r: Meeting) => <span className="text-sm tabular-nums">{fmtDate(r.meeting_date)}</span>,
    },
    {
      key: 'office',
      header: 'Family Office',
      render: (r: Meeting) => <span className="font-medium">{r.family_office_name}</span>,
    },
    {
      key: 'gen',
      header: 'Generation',
      render: (r: Meeting) => (
        <span className="rounded bg-indigo-50 px-2 py-0.5 text-xs font-medium text-indigo-700">
          {genLabel(r.generation_attended)}
        </span>
      ),
    },
    {
      key: 'attendees',
      header: 'Attendees',
      render: (r: Meeting) => {
        const emails = r.attendee_emails ?? [];
        return (
          <span className="text-xs text-[var(--color-muted)]">
            {emails.length > 0 ? emails.join(', ') : '—'}
          </span>
        );
      },
    },
    {
      key: 'topics',
      header: 'Key Topics',
      render: (r: Meeting) => (
        <span className="text-xs text-[var(--color-muted)]">
          {r.key_topics ? r.key_topics.slice(0, 120) : '—'}
        </span>
      ),
    },
    {
      key: 'followup',
      header: 'Follow-up',
      render: (r: Meeting) =>
        r.follow_up_required ? (
          <span className="rounded bg-rose-50 px-2 py-0.5 text-xs font-medium text-rose-700">
            Required
          </span>
        ) : (
          <span className="text-xs text-[var(--color-muted)]">—</span>
        ),
    },
  ];

  const generationColumns: Column<GenerationRow>[] = [
    {
      key: 'bucket',
      header: 'Generation Bucket',
      render: (r: GenerationRow) => <span className="font-medium">{genLabel(r.generation_bucket)}</span>,
    },
    {
      key: 'offices',
      header: 'Family Offices',
      render: (r: GenerationRow) => <span className="text-sm tabular-nums">{Number(r.office_count)}</span>,
    },
    {
      key: 'meetings',
      header: 'Meetings Logged',
      render: (r: GenerationRow) => <span className="text-sm tabular-nums">{Number(r.meeting_count)}</span>,
    },
    {
      key: 'engaged',
      header: 'Engaged Offices',
      render: (r: GenerationRow) => (
        <span className="text-sm tabular-nums text-green-700">{Number(r.engaged_offices)}</span>
      ),
    },
  ];

  return (
    <main className="mx-auto max-w-6xl space-y-8 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold text-[var(--color-foreground)]">
          Investor Family Office Tracker
        </h1>
        <p className="text-sm text-[var(--color-muted)]">
          Multi-generation family office relationship tracking. Engagement spans current generation,
          next-gen heirs & multi-gen perspectives. Round r1765.
        </p>
      </header>

      {anyErr ? (
        <div className="rounded border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
          Error loading data: {anyErr}
        </div>
      ) : null}

      <section className="space-y-3">
        <h2 className="text-lg font-medium text-[var(--color-foreground)]">Portfolio summary</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
          <div className="rounded border border-[var(--color-border)] bg-white p-3">
            <div className="text-xs text-[var(--color-muted)]">Total offices</div>
            <div className="mt-1 text-xl font-semibold tabular-nums">
              {Number(summaryRow?.total_count ?? 0)}
            </div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-3">
            <div className="text-xs text-[var(--color-muted)]">Engaged</div>
            <div className="mt-1 text-xl font-semibold tabular-nums text-green-700">
              {Number(summaryRow?.engaged_count ?? 0)}
            </div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-3">
            <div className="text-xs text-[var(--color-muted)]">Cultivating</div>
            <div className="mt-1 text-xl font-semibold tabular-nums text-amber-700">
              {Number(summaryRow?.cultivating_count ?? 0)}
            </div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-3">
            <div className="text-xs text-[var(--color-muted)]">Dormant</div>
            <div className="mt-1 text-xl font-semibold tabular-nums text-gray-600">
              {Number(summaryRow?.dormant_count ?? 0)}
            </div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-3">
            <div className="text-xs text-[var(--color-muted)]">Meetings (30d)</div>
            <div className="mt-1 text-xl font-semibold tabular-nums">
              {Number(summaryRow?.meetings_last_30d ?? 0)}
            </div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-3">
            <div className="text-xs text-[var(--color-muted)]">Follow-ups</div>
            <div className="mt-1 text-xl font-semibold tabular-nums text-rose-700">
              {Number(summaryRow?.follow_ups_pending ?? 0)}
            </div>
          </div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium text-[var(--color-foreground)]">
          Generation engagement breakdown
        </h2>
        <p className="text-xs text-[var(--color-muted)]">
          Pipeline split by generation focus. Multi-gen offices typically require &gt;= 2 distinct
          decision-makers per meeting.
        </p>
        <DataTable
          rows={generations}
          columns={generationColumns}
          rowKey={(r, i) => String(r.generation_bucket ?? i)}
          emptyMessage="No generation data yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium text-[var(--color-foreground)]">Family offices</h2>
        <DataTable
          rows={offices}
          columns={officeColumns}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No family offices tracked yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium text-[var(--color-foreground)]">
          Recent meetings (last 200)
        </h2>
        <DataTable
          rows={meetings}
          columns={meetingColumns}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No meetings logged yet."
        />
      </section>

      <footer className="border-t border-[var(--color-border)] pt-4 text-xs text-[var(--color-muted)]">
        Round r1765 · Founder-only view. All writes log to founder_action_log. Status transitions:
        cultivating → engaged → dormant.
      </footer>
    </main>
  );
}
