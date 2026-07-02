import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderMonthlyEmotionalResiliencePulsePage() {
  const supabase = await getSupabaseServerClient();

  const [
    pulsesRes,
    practiceLogsRes,
    topPracticeRes,
    scoreTrendRes,
    statusFunnelRes,
    lessonSummaryRes,
    pulseSummaryRes,
  ] = await Promise.all([
    supabase.rpc('list_resilience_r2629'),
    supabase.rpc('list_practice_outcomes_r2629'),
    supabase.rpc('top_practice_focus_r2629'),
    supabase.rpc('monthly_score_trend_r2629'),
    supabase.rpc('status_funnel_r2629'),
    supabase.rpc('lesson_summary_r2629'),
    supabase.rpc('founder_pulse_summary_r2629'),
  ]);

  const pulses = (pulsesRes.data ?? []) as any[];
  const practiceLogs = (practiceLogsRes.data ?? []) as any[];
  const topPractices = (topPracticeRes.data ?? []) as any[];
  const scoreTrend = (scoreTrendRes.data ?? []) as any[];
  const statusFunnel = (statusFunnelRes.data ?? []) as any[];
  const lessonSummary = (lessonSummaryRes.data ?? []) as any[];
  const summary = (pulseSummaryRes.data ?? [])[0] as any;

  const pulseColumns: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'resilience_score', header: 'Resilience', render: (r: any) => `${r.resilience_score}/100` },
    { key: 'stress_score', header: 'Stress', render: (r: any) => `${r.stress_score}/10` },
    { key: 'biggest_test_md', header: 'Biggest Test', render: (r: any) => r.biggest_test_md ?? '' },
    { key: 'lesson_md', header: 'Lesson', render: (r: any) => r.lesson_md ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
  ];

  const practiceColumns: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label ?? '' },
    { key: 'observed_at', header: 'Observed', render: (r: any) => r.observed_at ? new Date(r.observed_at).toLocaleDateString() : '' },
    { key: 'practice_kind', header: 'Practice', render: (r: any) => r.practice_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const topPracticeColumns: Column<any>[] = [
    { key: 'practice_kind', header: 'Practice', render: (r: any) => r.practice_kind },
    { key: 'entry_count', header: 'Total Logs', render: (r: any) => String(r.entry_count) },
    { key: 'positive_count', header: 'Positive', render: (r: any) => String(r.positive_count) },
    { key: 'positive_rate', header: 'Positive %', render: (r: any) => r.positive_rate ? `${Number(r.positive_rate).toFixed(1)}%` : '0%' },
  ];

  const trendColumns: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'resilience_score', header: 'Resilience', render: (r: any) => `${r.resilience_score}/100` },
    { key: 'stress_score', header: 'Stress', render: (r: any) => `${r.stress_score}/10` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const funnelColumns: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'entry_count', header: 'Count', render: (r: any) => String(r.entry_count) },
    { key: 'avg_resilience', header: 'Avg Resilience', render: (r: any) => r.avg_resilience ? Number(r.avg_resilience).toFixed(1) : '0' },
    { key: 'avg_stress', header: 'Avg Stress', render: (r: any) => r.avg_stress ? Number(r.avg_stress).toFixed(1) : '0' },
  ];

  const lessonColumns: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'resilience_score', header: 'Resilience', render: (r: any) => `${r.resilience_score}/100` },
    { key: 'lesson_md', header: 'Lesson', render: (r: any) => r.lesson_md ?? '' },
    { key: 'biggest_test_md', header: 'Biggest Test', render: (r: any) => r.biggest_test_md ?? '' },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
        Founder Monthly Emotional Resilience Pulse
      </h1>
      <p style={{ color: '#6b7280', marginBottom: '24px' }}>
        Monthly resilience scores, biggest tests, lessons & recovery practice outcomes
      </p>

      {summary && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '32px' }}>
          <div style={{ padding: '16px', background: '#f9fafb', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#6b7280' }}>Total Pulses</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{summary.total_pulses}</div>
          </div>
          <div style={{ padding: '16px', background: '#f9fafb', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#6b7280' }}>Avg Resilience</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{Number(summary.avg_resilience ?? 0).toFixed(1)}/100</div>
          </div>
          <div style={{ padding: '16px', background: '#f9fafb', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#6b7280' }}>Avg Stress</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{Number(summary.avg_stress ?? 0).toFixed(1)}/10</div>
          </div>
          <div style={{ padding: '16px', background: '#f9fafb', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#6b7280' }}>Done</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{summary.done_count}</div>
          </div>
          <div style={{ padding: '16px', background: '#f9fafb', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#6b7280' }}>Draft</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{summary.draft_count}</div>
          </div>
          <div style={{ padding: '16px', background: '#f9fafb', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#6b7280' }}>Practice Logs</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{summary.total_practice_logs}</div>
          </div>
          <div style={{ padding: '16px', background: '#f9fafb', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#6b7280' }}>Positive Outcomes</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{summary.positive_outcomes}</div>
          </div>
        </div>
      )}

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Monthly Pulses</h2>
        <DataTable
          rows={pulses}
          columns={pulseColumns}
          emptyMessage="No resilience pulses recorded yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Practice Outcomes Log</h2>
        <DataTable
          rows={practiceLogs}
          columns={practiceColumns}
          emptyMessage="No practice outcomes logged yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Top Practice Focus</h2>
        <DataTable
          rows={topPractices}
          columns={topPracticeColumns}
          emptyMessage="No practice data"
          rowKey={(r: any, i: number) => String(r.practice_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Monthly Score Trend</h2>
        <DataTable
          rows={scoreTrend}
          columns={trendColumns}
          emptyMessage="No trend data"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Status Funnel</h2>
        <DataTable
          rows={statusFunnel}
          columns={funnelColumns}
          emptyMessage="No status data"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Lesson Summary</h2>
        <DataTable
          rows={lessonSummary}
          columns={lessonColumns}
          emptyMessage="No lessons recorded yet"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>
    </div>
  );
}
