import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type StandupRow = {
  id: string;
  standup_date: string;
  attendees: string[] | null;
  attendee_count: number | null;
  main_topics_md: string | null;
  blockers_md: string | null;
  status: string | null;
  recorded_at: string | null;
  outcome_count: number | null;
};

type OutcomeRow = {
  id: string;
  standup_id: string;
  standup_date: string | null;
  outcome_type: string | null;
  taken_at: string | null;
  by_email: string | null;
  notes_md: string | null;
};

type TrendRow = {
  standup_date: string;
  attendee_count: number | null;
  status: string | null;
};

type RecentOutcomeRow = {
  outcome_type: string | null;
  outcome_count: number | null;
  last_at: string | null;
};

export default async function FounderDailyStandupTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [standupsRes, outcomesRes, trendRes, recentRes] = await Promise.all([
    sb.rpc('list_standups_r1982', { p_limit: 50 }),
    sb.rpc('list_outcomes_r1982', { p_standup_id: null, p_limit: 100 }),
    sb.rpc('attendance_trend_r1982', { p_days: 30 }),
    sb.rpc('recent_outcomes_r1982', { p_limit: 25 }),
  ]);

  const standups: StandupRow[] = Array.isArray(standupsRes.data) ? (standupsRes.data as StandupRow[]) : [];
  const outcomes: OutcomeRow[] = Array.isArray(outcomesRes.data) ? (outcomesRes.data as OutcomeRow[]) : [];
  const trend: TrendRow[] = Array.isArray(trendRes.data) ? (trendRes.data as TrendRow[]) : [];
  const recent: RecentOutcomeRow[] = Array.isArray(recentRes.data) ? (recentRes.data as RecentOutcomeRow[]) : [];

  const totalStandups = standups.length;
  const heldCount = standups.filter((s) => s.status === 'held').length;
  const skippedCount = standups.filter((s) => s.status === 'skipped').length;
  const postponedCount = standups.filter((s) => s.status === 'postponed').length;
  const avgAttendees = trend.length
    ? Math.round(
        (trend.reduce((acc, t) => acc + (t.attendee_count ?? 0), 0) / trend.length) * 10
      ) / 10
    : 0;

  const standupColumns: Column<StandupRow>[] = [
    { key: 'standup_date', header: 'Date', render: (r: any) => String(r.standup_date ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'attendee_count', header: 'Attendees', render: (r: any) => String(r.attendee_count ?? 0) },
    { key: 'attendees', header: 'Names', render: (r: any) => Array.isArray(r.attendees) ? r.attendees.join(', ') : '' },
    { key: 'outcome_count', header: 'Outcomes', render: (r: any) => String(r.outcome_count ?? 0) },
    { key: 'main_topics_md', header: 'Topics', render: (r: any) => (r.main_topics_md ?? '').slice(0, 60) },
    { key: 'blockers_md', header: 'Blockers', render: (r: any) => (r.blockers_md ?? '').slice(0, 60) },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '' },
  ];

  const outcomeColumns: Column<OutcomeRow>[] = [
    { key: 'standup_date', header: 'Standup Date', render: (r: any) => String(r.standup_date ?? '') },
    { key: 'outcome_type', header: 'Type', render: (r: any) => String(r.outcome_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => (r.notes_md ?? '').slice(0, 100) },
  ];

  const trendColumns: Column<TrendRow>[] = [
    { key: 'standup_date', header: 'Date', render: (r: any) => String(r.standup_date ?? '') },
    { key: 'attendee_count', header: 'Attendees', render: (r: any) => String(r.attendee_count ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const recentColumns: Column<RecentOutcomeRow>[] = [
    { key: 'outcome_type', header: 'Outcome Type', render: (r: any) => String(r.outcome_type ?? '') },
    { key: 'outcome_count', header: 'Count', render: (r: any) => String(r.outcome_count ?? 0) },
    { key: 'last_at', header: 'Last Seen', render: (r: any) => r.last_at ? new Date(r.last_at).toLocaleString() : '' },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder Daily Standup Tracker</h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Track daily standup attendance and outcomes. Log decisions, blockers resolved, escalations, celebrations and pivots.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 12, marginBottom: 24 }}>
        <Card label="Total Standups" value={String(totalStandups)} />
        <Card label="Held" value={String(heldCount)} />
        <Card label="Skipped" value={String(skippedCount)} />
        <Card label="Postponed" value={String(postponedCount)} />
        <Card label="Avg Attendees (30d)" value={String(avgAttendees)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Standups</h2>
        <DataTable rows={standups} columns={standupColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Outcome Log</h2>
        <DataTable rows={outcomes} columns={outcomeColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Attendance Trend (last 30 days)</h2>
        <DataTable rows={trend} columns={trendColumns} rowKey={(r: any, i: number) => String(r.standup_date ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Outcome Type Summary</h2>
        <DataTable rows={recent} columns={recentColumns} rowKey={(r: any, i: number) => String(r.outcome_type ?? i)} />
      </section>
    </div>
  );
}

function Card({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12, background: '#fafafa' }}>
      <div style={{ fontSize: 12, color: '#666' }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}
