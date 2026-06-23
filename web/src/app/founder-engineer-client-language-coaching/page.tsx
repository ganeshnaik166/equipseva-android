import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    sessionsRes,
    outcomesRes,
    liftersRes,
    focusRes,
    trendRes,
    hospitalRes,
    ownerRes,
  ] = await Promise.all([
    supabase.rpc('list_coaching_sessions_r2550'),
    supabase.rpc('list_outcomes_r2550'),
    supabase.rpc('top_confidence_lifters_r2550'),
    supabase.rpc('focus_kind_breakdown_r2550'),
    supabase.rpc('monthly_coaching_trend_r2550'),
    supabase.rpc('hospital_impact_summary_r2550'),
    supabase.rpc('owner_load_r2550'),
  ]);

  const sessions = (sessionsRes.data ?? []) as any[];
  const outcomes = (outcomesRes.data ?? []) as any[];
  const lifters = (liftersRes.data ?? []) as any[];
  const focus = (focusRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const hospital = (hospitalRes.data ?? []) as any[];
  const owner = (ownerRes.data ?? []) as any[];

  const fmtDate = (v: any) => (v ? new Date(v).toLocaleString() : '—');
  const fmtMonth = (v: any) =>
    v ? new Date(v).toLocaleDateString(undefined, { year: 'numeric', month: 'short' }) : '—';
  const shortId = (v: any) => (v ? String(v).slice(0, 8) : '—');

  const sessionsCols: Column<any>[] = [
    { key: 'session_at', header: 'Session At', render: (r: any) => fmtDate(r.session_at) },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => shortId(r.engineer_user_id) },
    { key: 'language_name', header: 'Language', render: (r: any) => r.language_name ?? '—' },
    { key: 'focus_kind', header: 'Focus', render: (r: any) => r.focus_kind ?? '—' },
    { key: 'coach_email', header: 'Coach', render: (r: any) => r.coach_email ?? '—' },
    { key: 'duration_minutes', header: 'Min', render: (r: any) => r.duration_minutes ?? '—' },
    { key: 'confidence_pre', header: 'Pre', render: (r: any) => r.confidence_pre ?? '—' },
    { key: 'confidence_post', header: 'Post', render: (r: any) => r.confidence_post ?? '—' },
    { key: 'confidence_delta', header: 'Δ', render: (r: any) => r.confidence_delta ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
  ];

  const outcomesCols: Column<any>[] = [
    { key: 'observed_at', header: 'Observed', render: (r: any) => fmtDate(r.observed_at) },
    { key: 'session_id', header: 'Session', render: (r: any) => shortId(r.session_id) },
    { key: 'hospital_user_id', header: 'Hospital', render: (r: any) => shortId(r.hospital_user_id) },
    { key: 'hospital_csat_delta', header: 'CSAT Δ', render: (r: any) => r.hospital_csat_delta ?? '—' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const liftersCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => shortId(r.engineer_user_id) },
    { key: 'sessions_count', header: 'Sessions', render: (r: any) => r.sessions_count ?? 0 },
    { key: 'avg_delta', header: 'Avg Δ', render: (r: any) => r.avg_delta ?? '—' },
    { key: 'max_delta', header: 'Max Δ', render: (r: any) => r.max_delta ?? '—' },
    { key: 'total_minutes', header: 'Total Min', render: (r: any) => r.total_minutes ?? 0 },
  ];

  const focusCols: Column<any>[] = [
    { key: 'focus_kind', header: 'Focus', render: (r: any) => r.focus_kind ?? '—' },
    { key: 'sessions_count', header: 'Sessions', render: (r: any) => r.sessions_count ?? 0 },
    { key: 'avg_delta', header: 'Avg Δ', render: (r: any) => r.avg_delta ?? '—' },
    { key: 'avg_duration', header: 'Avg Min', render: (r: any) => r.avg_duration ?? '—' },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count ?? 0 },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => fmtMonth(r.month_start) },
    { key: 'sessions_count', header: 'Sessions', render: (r: any) => r.sessions_count ?? 0 },
    { key: 'avg_delta', header: 'Avg Δ', render: (r: any) => r.avg_delta ?? '—' },
    { key: 'total_minutes', header: 'Total Min', render: (r: any) => r.total_minutes ?? 0 },
  ];

  const hospitalCols: Column<any>[] = [
    { key: 'hospital_user_id', header: 'Hospital', render: (r: any) => shortId(r.hospital_user_id) },
    { key: 'outcomes_count', header: 'Outcomes', render: (r: any) => r.outcomes_count ?? 0 },
    { key: 'avg_csat_delta', header: 'Avg CSAT Δ', render: (r: any) => r.avg_csat_delta ?? '—' },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count ?? 0 },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count ?? 0 },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'outcomes_count', header: 'Total', render: (r: any) => r.outcomes_count ?? 0 },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count ?? 0 },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count ?? 0 },
    { key: 'dropped_count', header: 'Dropped', render: (r: any) => r.dropped_count ?? 0 },
    { key: 'avg_csat_delta', header: 'Avg CSAT Δ', render: (r: any) => r.avg_csat_delta ?? '—' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Engineer Client-Language Coaching
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Engineer × language gap × coaching session × outcome × confidence delta × hospital impact.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Coaching Sessions</h2>
        <DataTable
          rows={sessions}
          columns={sessionsCols}
          emptyMessage="No coaching sessions yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Outcomes</h2>
        <DataTable
          rows={outcomes}
          columns={outcomesCols}
          emptyMessage="No outcomes logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Confidence Lifters</h2>
        <DataTable
          rows={lifters}
          columns={liftersCols}
          emptyMessage="No engineers with completed sessions."
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Focus Kind Breakdown</h2>
        <DataTable
          rows={focus}
          columns={focusCols}
          emptyMessage="No focus data."
          rowKey={(r: any, i: number) => String(r.focus_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Hospital Impact Summary</h2>
        <DataTable
          rows={hospital}
          columns={hospitalCols}
          emptyMessage="No hospital impact recorded."
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Owner Load</h2>
        <DataTable
          rows={owner}
          columns={ownerCols}
          emptyMessage="No owner data."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </main>
  );
}
