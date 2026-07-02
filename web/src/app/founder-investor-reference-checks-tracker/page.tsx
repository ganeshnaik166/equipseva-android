import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type CheckRow = {
  id: string;
  investor_id: string | null;
  referee_name: string;
  referee_role: string;
  contacted_at: string | null;
  sentiment: string | null;
  key_themes_md: string | null;
  status: string;
  founder_takeaway_md: string | null;
  created_at: string;
};

type ThemeRow = {
  sentiment: string;
  check_count: number;
  pending_count: number;
  completed_count: number;
};

type RecentResponseRow = {
  id: string;
  check_id: string;
  referee_name: string | null;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  note_md: string | null;
};

function fmt(d: string | null | undefined) {
  if (!d) return '—';
  try {
    return new Date(d).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return d;
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [checksRes, themesRes, recentRes] = await Promise.all([
    sb.rpc('list_investor_reference_checks_r1913'),
    sb.rpc('top_investor_reference_themes_r1913'),
    sb.rpc('recent_investor_reference_responses_r1913'),
  ]);

  const checks: CheckRow[] = (checksRes.data as CheckRow[] | null) ?? [];
  const themes: ThemeRow[] = (themesRes.data as ThemeRow[] | null) ?? [];
  const recent: RecentResponseRow[] = (recentRes.data as RecentResponseRow[] | null) ?? [];

  const totalChecks = checks.length;
  const pendingChecks = checks.filter((c) => c.status === 'pending').length;
  const completedChecks = checks.filter((c) => c.status === 'completed').length;
  const declinedChecks = checks.filter((c) => c.status === 'declined').length;
  const positiveCount = checks.filter(
    (c) => c.sentiment === 'positive' || c.sentiment === 'very_positive',
  ).length;
  const concernsCount = checks.filter(
    (c) => c.sentiment === 'concerns' || c.sentiment === 'negative',
  ).length;

  const checkCols: Column<CheckRow>[] = [
    { key: 'referee_name', header: 'Referee', render: (r: any) => r.referee_name ?? '—' },
    { key: 'referee_role', header: 'Role', render: (r: any) => r.referee_role ?? '—' },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => r.sentiment ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'contacted_at', header: 'Contacted', render: (r: any) => fmt(r.contacted_at) },
    {
      key: 'key_themes_md',
      header: 'Themes',
      render: (r: any) => (r.key_themes_md ? String(r.key_themes_md).slice(0, 80) : '—'),
    },
    {
      key: 'founder_takeaway_md',
      header: 'Takeaway',
      render: (r: any) => (r.founder_takeaway_md ? String(r.founder_takeaway_md).slice(0, 80) : '—'),
    },
    { key: 'created_at', header: 'Logged', render: (r: any) => fmt(r.created_at) },
  ];

  const themeCols: Column<ThemeRow>[] = [
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => r.sentiment ?? '—' },
    { key: 'check_count', header: 'Checks', render: (r: any) => String(r.check_count ?? 0) },
    { key: 'pending_count', header: 'Pending', render: (r: any) => String(r.pending_count ?? 0) },
    {
      key: 'completed_count',
      header: 'Completed',
      render: (r: any) => String(r.completed_count ?? 0),
    },
  ];

  const recentCols: Column<RecentResponseRow>[] = [
    { key: 'referee_name', header: 'Referee', render: (r: any) => r.referee_name ?? '—' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '—' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'taken_at', header: 'When', render: (r: any) => fmt(r.taken_at) },
    {
      key: 'note_md',
      header: 'Note',
      render: (r: any) => (r.note_md ? String(r.note_md).slice(0, 100) : '—'),
    },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1280px', margin: '0 auto' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
          Investor Reference Checks Tracker
        </h1>
        <p style={{ color: '#666', fontSize: '14px' }}>
          Track reference checks investors run on us & capture sentiment plus themes.
        </p>
      </header>

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
          gap: '12px',
          marginBottom: '24px',
        }}
      >
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Total checks</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{totalChecks}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Pending</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{pendingChecks}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Completed</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{completedChecks}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Declined</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{declinedChecks}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Positive sentiment</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{positiveCount}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Concerns raised</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{concernsCount}</div>
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>
          All reference checks
        </h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
          Most recent first. Up to 200 rows shown.
        </p>
        <DataTable
          rows={checks}
          columns={checkCols}
          rowKey={(r, i) => String((r as any).id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>
          Sentiment breakdown
        </h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
          Aggregated by sentiment bucket across all logged checks.
        </p>
        <DataTable
          rows={themes}
          columns={themeCols}
          rowKey={(r, i) => String((r as any).sentiment ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>
          Recent response activity
        </h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
          Latest follow-ups, notes & founder actions logged against any check.
        </p>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r, i) => String((r as any).id ?? i)}
        />
      </section>
    </div>
  );
}
