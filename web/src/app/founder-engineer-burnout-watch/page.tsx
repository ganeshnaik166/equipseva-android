import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Signal = {
  id: string;
  engineer_user_id: string;
  engineer_name: string;
  window_start: string;
  window_end: string;
  jobs_in_window: number;
  after_hours_pct: number;
  weekend_pct: number;
  leave_days: number;
  signal_score: number;
  recorded_at: string;
};

type TopEngineer = {
  engineer_user_id: string;
  engineer_name: string;
  latest_signal_score: number;
  latest_jobs: number;
  latest_after_hours_pct: number;
  latest_weekend_pct: number;
  latest_recorded_at: string;
};

type Intervention = {
  id: string;
  signal_id: string;
  engineer_name: string;
  intervention_type: string;
  taken_by_email: string;
  taken_at: string;
  note: string | null;
  outcome: string | null;
};

type Summary = {
  total_signals: number;
  engineers_tracked: number;
  high_risk_count: number;
  avg_signal_score: number;
  max_signal_score: number;
  interventions_logged: number;
  last_computed_at: string | null;
};

type Trend = {
  bucket_date: string;
  signals_recorded: number;
  avg_score: number;
  max_score: number;
  high_risk_count: number;
};

export default async function FounderEngineerBurnoutWatchPage() {
  const sb = await getSupabaseServerClient();

  const [summaryRes, signalsRes, topRes, interventionsRes, trendRes] = await Promise.all([
    sb.rpc('founder_burnout_summary_r1664'),
    sb.rpc('founder_list_burnout_signals_r1664', { p_limit: 100 }),
    sb.rpc('founder_top_burnout_engineers_r1664', { p_limit: 10 }),
    sb.rpc('founder_list_interventions_r1664', { p_limit: 50 }),
    sb.rpc('founder_burnout_trend_r1664', { p_days: 30 }),
  ]);

  const summary: Summary = (Array.isArray(summaryRes.data) ? summaryRes.data[0] : summaryRes.data) ?? {
    total_signals: 0,
    engineers_tracked: 0,
    high_risk_count: 0,
    avg_signal_score: 0,
    max_signal_score: 0,
    interventions_logged: 0,
    last_computed_at: null,
  };
  const signals: Signal[] = (signalsRes.data ?? []) as Signal[];
  const top: TopEngineer[] = (topRes.data ?? []) as TopEngineer[];
  const interventions: Intervention[] = (interventionsRes.data ?? []) as Intervention[];
  const trend: Trend[] = (trendRes.data ?? []) as Trend[];

  const fmtPct = (v: number | null | undefined) =>
    v == null ? '—' : `${Number(v).toFixed(1)}%`;
  const fmtDate = (v: string | null | undefined) =>
    v ? new Date(v).toLocaleString() : '—';
  const fmtDay = (v: string | null | undefined) =>
    v ? new Date(v).toLocaleDateString() : '—';

  const riskBadge = (score: number) => {
    if (score >= 70) return <span style={{ color: '#b91c1c', fontWeight: 600 }}>HIGH</span>;
    if (score >= 40) return <span style={{ color: '#b45309', fontWeight: 600 }}>MED</span>;
    return <span style={{ color: '#15803d', fontWeight: 600 }}>LOW</span>;
  };

  const topCols: Column<TopEngineer>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'latest_signal_score', header: 'Score', render: (r) => Number(r.latest_signal_score).toFixed(1) },
    { key: 'risk', header: 'Risk', render: (r) => riskBadge(Number(r.latest_signal_score)) },
    { key: 'latest_jobs', header: 'Jobs', render: (r) => r.latest_jobs },
    { key: 'latest_after_hours_pct', header: 'After-Hours', render: (r) => fmtPct(r.latest_after_hours_pct) },
    { key: 'latest_weekend_pct', header: 'Weekend', render: (r) => fmtPct(r.latest_weekend_pct) },
    { key: 'latest_recorded_at', header: 'Last Computed', render: (r) => fmtDate(r.latest_recorded_at) },
  ];

  const signalCols: Column<Signal>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'signal_score', header: 'Score', render: (r) => Number(r.signal_score).toFixed(1) },
    { key: 'risk', header: 'Risk', render: (r) => riskBadge(Number(r.signal_score)) },
    { key: 'jobs_in_window', header: 'Jobs', render: (r) => r.jobs_in_window },
    { key: 'after_hours_pct', header: 'After-Hours', render: (r) => fmtPct(r.after_hours_pct) },
    { key: 'weekend_pct', header: 'Weekend', render: (r) => fmtPct(r.weekend_pct) },
    { key: 'leave_days', header: 'Leave', render: (r) => r.leave_days },
    { key: 'window', header: 'Window', render: (r) => `${fmtDay(r.window_start)} → ${fmtDay(r.window_end)}` },
    { key: 'recorded_at', header: 'Recorded', render: (r) => fmtDate(r.recorded_at) },
  ];

  const interventionCols: Column<Intervention>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'intervention_type', header: 'Type', render: (r) => r.intervention_type },
    { key: 'taken_by_email', header: 'By', render: (r) => r.taken_by_email },
    { key: 'taken_at', header: 'Taken', render: (r) => fmtDate(r.taken_at) },
    { key: 'note', header: 'Note', render: (r) => r.note ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r) => r.outcome ?? '—' },
  ];

  const trendCols: Column<Trend>[] = [
    { key: 'bucket_date', header: 'Date', render: (r) => fmtDay(r.bucket_date) },
    { key: 'signals_recorded', header: 'Signals', render: (r) => r.signals_recorded },
    { key: 'avg_score', header: 'Avg Score', render: (r) => Number(r.avg_score).toFixed(1) },
    { key: 'max_score', header: 'Max Score', render: (r) => Number(r.max_score).toFixed(1) },
    { key: 'high_risk_count', header: 'High Risk', render: (r) => r.high_risk_count },
  ];

  const kpiCard = (label: string, value: string | number) => (
    <div style={{
      padding: '16px',
      border: '1px solid #e5e7eb',
      borderRadius: '8px',
      background: '#fff',
      minWidth: '160px',
    }}>
      <div style={{ fontSize: '12px', color: '#6b7280', textTransform: 'uppercase', letterSpacing: '0.05em' }}>{label}</div>
      <div style={{ fontSize: '24px', fontWeight: 700, color: '#111827', marginTop: '4px' }}>{value}</div>
    </div>
  );

  return (
    <main style={{ padding: '24px', maxWidth: '1280px', margin: '0 auto' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700, margin: 0 }}>Engineer Burnout Watch</h1>
        <p style={{ color: '#6b7280', marginTop: '4px' }}>
          r1664 — jobs/week, after-hours, weekend load, leave usage, composite signal score.
        </p>
      </header>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Summary KPIs</h2>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '12px' }}>
          {kpiCard('Total Signals', summary.total_signals)}
          {kpiCard('Engineers Tracked', summary.engineers_tracked)}
          {kpiCard('High Risk (≥70)', summary.high_risk_count)}
          {kpiCard('Avg Score', Number(summary.avg_signal_score).toFixed(1))}
          {kpiCard('Max Score', Number(summary.max_signal_score).toFixed(1))}
          {kpiCard('Interventions', summary.interventions_logged)}
          {kpiCard('Last Computed', fmtDate(summary.last_computed_at))}
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Top Burnout Risk Engineers</h2>
        <DataTable
          rows={top}
          columns={topCols}
          rowKey={(r, i) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>All Recent Signals</h2>
        <DataTable
          rows={signals}
          columns={signalCols}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Intervention Action Queue</h2>
        <DataTable
          rows={interventions}
          columns={interventionCols}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>30-Day Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          rowKey={(r, i) => String(r.bucket_date ?? i)}
        />
      </section>
    </main>
  );
}
