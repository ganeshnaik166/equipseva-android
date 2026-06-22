import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [summaryRes, queueRes, scoresRes, leaderRes, poolRes, flaggedRes, distRes, trendRes] = await Promise.all([
    sb.rpc('fn_evca_summary_r2238'),
    sb.rpc('fn_evca_pending_queue_r2238'),
    sb.rpc('fn_evca_recent_scores_r2238'),
    sb.rpc('fn_evca_engineer_leaderboard_r2238'),
    sb.rpc('fn_evca_pool_breakdown_r2238'),
    sb.rpc('fn_evca_flagged_calls_r2238'),
    sb.rpc('fn_evca_score_distribution_r2238'),
    sb.rpc('fn_evca_weekly_trend_r2238'),
  ]);

  const summary: any = (summaryRes.data && (summaryRes.data as any[])[0]) || {};
  const queue: any[] = (queueRes.data as any[]) || [];
  const scores: any[] = (scoresRes.data as any[]) || [];
  const leaders: any[] = (leaderRes.data as any[]) || [];
  const pools: any[] = (poolRes.data as any[]) || [];
  const flagged: any[] = (flaggedRes.data as any[]) || [];
  const dist: any[] = (distRes.data as any[]) || [];
  const trend: any[] = (trendRes.data as any[]) || [];

  const queueCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '—') },
    { key: 'call_started_at', header: 'Call Start', render: (r: any) => String(r.call_started_at ? new Date(r.call_started_at).toLocaleString() : '—') },
    { key: 'duration_seconds', header: 'Duration (s)', render: (r: any) => String(r.duration_seconds ?? 0) },
    { key: 'direction', header: 'Direction', render: (r: any) => String(r.direction ?? '') },
    { key: 'sampling_pool', header: 'Pool', render: (r: any) => String(r.sampling_pool ?? '') },
    { key: 'customer_phone_masked', header: 'Customer', render: (r: any) => String(r.customer_phone_masked ?? '—') },
    { key: 'days_waiting', header: 'Days Waiting', render: (r: any) => String(r.days_waiting ?? 0) },
  ];

  const scoreCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '—') },
    { key: 'call_started_at', header: 'Call', render: (r: any) => String(r.call_started_at ? new Date(r.call_started_at).toLocaleDateString() : '—') },
    { key: 'tone', header: 'Tone', render: (r: any) => String(r.tone ?? 0) },
    { key: 'clarity', header: 'Clarity', render: (r: any) => String(r.clarity ?? 0) },
    { key: 'empathy', header: 'Empathy', render: (r: any) => String(r.empathy ?? 0) },
    { key: 'resolution', header: 'Resolution', render: (r: any) => String(r.resolution ?? 0) },
    { key: 'composite', header: 'Composite', render: (r: any) => String(r.composite ?? 0) },
    { key: 'followup', header: 'Followup', render: (r: any) => String(r.followup ? 'YES' : 'no') },
    { key: 'scored_by', header: 'Scored By', render: (r: any) => String(r.scored_by ?? '') },
  ];

  const leaderCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '—') },
    { key: 'calls_audited', header: 'Audited', render: (r: any) => String(r.calls_audited ?? 0) },
    { key: 'calls_scored', header: 'Scored', render: (r: any) => String(r.calls_scored ?? 0) },
    { key: 'avg_tone', header: 'Tone', render: (r: any) => String(r.avg_tone ?? 0) },
    { key: 'avg_clarity', header: 'Clarity', render: (r: any) => String(r.avg_clarity ?? 0) },
    { key: 'avg_empathy', header: 'Empathy', render: (r: any) => String(r.avg_empathy ?? 0) },
    { key: 'avg_resolution', header: 'Resolution', render: (r: any) => String(r.avg_resolution ?? 0) },
    { key: 'avg_composite', header: 'Composite', render: (r: any) => String(r.avg_composite ?? 0) },
    { key: 'flag_rate_pct', header: 'Flag %', render: (r: any) => String(r.flag_rate_pct ?? 0) },
  ];

  const poolCols: Column<any>[] = [
    { key: 'sampling_pool', header: 'Pool', render: (r: any) => String(r.sampling_pool ?? '') },
    { key: 'total', header: 'Total', render: (r: any) => String(r.total ?? 0) },
    { key: 'scored', header: 'Scored', render: (r: any) => String(r.scored ?? 0) },
    { key: 'flagged', header: 'Flagged', render: (r: any) => String(r.flagged ?? 0) },
    { key: 'avg_composite', header: 'Avg Composite', render: (r: any) => String(r.avg_composite ?? 0) },
  ];

  const flaggedCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '—') },
    { key: 'call_started_at', header: 'Call', render: (r: any) => String(r.call_started_at ? new Date(r.call_started_at).toLocaleDateString() : '—') },
    { key: 'composite', header: 'Composite', render: (r: any) => String(r.composite ?? 0) },
    { key: 'coaching_note', header: 'Coaching Note', render: (r: any) => String(r.coaching_note ?? '—') },
    { key: 'scored_at', header: 'Scored', render: (r: any) => String(r.scored_at ? new Date(r.scored_at).toLocaleDateString() : '—') },
  ];

  const distCols: Column<any>[] = [
    { key: 'dimension', header: 'Dimension', render: (r: any) => String(r.dimension ?? '') },
    { key: 'score_1', header: '1 star', render: (r: any) => String(r.score_1 ?? 0) },
    { key: 'score_2', header: '2 star', render: (r: any) => String(r.score_2 ?? 0) },
    { key: 'score_3', header: '3 star', render: (r: any) => String(r.score_3 ?? 0) },
    { key: 'score_4', header: '4 star', render: (r: any) => String(r.score_4 ?? 0) },
    { key: 'score_5', header: '5 star', render: (r: any) => String(r.score_5 ?? 0) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '—') },
    { key: 'calls_sampled', header: 'Sampled', render: (r: any) => String(r.calls_sampled ?? 0) },
    { key: 'calls_scored', header: 'Scored', render: (r: any) => String(r.calls_scored ?? 0) },
    { key: 'calls_flagged', header: 'Flagged', render: (r: any) => String(r.calls_flagged ?? 0) },
    { key: 'avg_composite', header: 'Avg Composite', render: (r: any) => String(r.avg_composite ?? 0) },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>Engineer Voice Call Quality Audit</h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Random sampling of recorded customer calls. Founder rates tone, clarity, empathy & resolution on a 1–5 scale. Low scores flag the engineer for coaching.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '24px' }}>
        <div style={{ background: '#f5f5f5', padding: '16px', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Total Calls Sampled</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{String(summary.total_calls ?? 0)}</div>
        </div>
        <div style={{ background: '#fff8e1', padding: '16px', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Pending Review</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{String(summary.pending_calls ?? 0)}</div>
        </div>
        <div style={{ background: '#e8f5e9', padding: '16px', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Scored</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{String(summary.scored_calls ?? 0)}</div>
        </div>
        <div style={{ background: '#ffebee', padding: '16px', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Flagged</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{String(summary.flagged_calls ?? 0)}</div>
        </div>
        <div style={{ background: '#e3f2fd', padding: '16px', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Avg Composite (1–5)</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{String(summary.avg_composite ?? 0)}</div>
        </div>
        <div style={{ background: '#f3e5f5', padding: '16px', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Last 7 Days</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{String(summary.calls_last_7d ?? 0)}</div>
        </div>
        <div style={{ background: '#fce4ec', padding: '16px', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Followup Required</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{String(summary.followup_required ?? 0)}</div>
        </div>
      </div>

      <h2 style={{ fontSize: '20px', fontWeight: 600, marginTop: '32px', marginBottom: '12px' }}>Pending Review Queue</h2>
      <p style={{ color: '#666', marginBottom: '12px' }}>Calls awaiting founder scoring. Oldest first.</p>
      <DataTable columns={queueCols} rows={queue} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: '20px', fontWeight: 600, marginTop: '32px', marginBottom: '12px' }}>Recently Scored Calls</h2>
      <DataTable columns={scoreCols} rows={scores} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: '20px', fontWeight: 600, marginTop: '32px', marginBottom: '12px' }}>Engineer Leaderboard</h2>
      <p style={{ color: '#666', marginBottom: '12px' }}>Top engineers by avg composite score. Higher composite &gt; 4.0 indicates strong customer-facing voice quality.</p>
      <DataTable columns={leaderCols} rows={leaders} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: '20px', fontWeight: 600, marginTop: '32px', marginBottom: '12px' }}>Sampling Pool Breakdown</h2>
      <p style={{ color: '#666', marginBottom: '12px' }}>Random vs escalation vs low-CSAT vs high-value pool comparison.</p>
      <DataTable columns={poolCols} rows={pools} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: '20px', fontWeight: 600, marginTop: '32px', marginBottom: '12px' }}>Flagged Calls & Coaching Notes</h2>
      <DataTable columns={flaggedCols} rows={flagged} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: '20px', fontWeight: 600, marginTop: '32px', marginBottom: '12px' }}>Score Distribution by Dimension</h2>
      <DataTable columns={distCols} rows={dist} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: '20px', fontWeight: 600, marginTop: '32px', marginBottom: '12px' }}>Weekly Trend (last 12 weeks)</h2>
      <DataTable columns={trendCols} rows={trend} rowKey={(_, i) => String(i)} />
    </div>
  );
}
