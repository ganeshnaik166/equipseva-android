import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtInt(n: any): string {
  const v = Number(n);
  if (!Number.isFinite(v)) return '—';
  return v.toLocaleString('en-IN');
}

function fmtNum(n: any, digits = 2): string {
  const v = Number(n);
  if (!Number.isFinite(v)) return '—';
  return v.toFixed(digits);
}

function fmtRupees(n: any): string {
  const v = Number(n);
  if (!Number.isFinite(v)) return '—';
  return '₹' + v.toLocaleString('en-IN');
}

function fmtDate(s: any): string {
  if (!s) return '—';
  try {
    return new Date(String(s)).toLocaleString('en-IN');
  } catch {
    return String(s);
  }
}

export default async function FounderEngineerExitInterviewPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let overview: any = {};
  let interviews: any[] = [];
  let byReason: any[] = [];
  let tenureBuckets: any[] = [];
  let sentimentDist: any[] = [];
  let patterns: any[] = [];

  try {
    const r = await sb.rpc('rpc_founder_exit_iv_overview');
    overview = (r.data as any) ?? {};
  } catch {
    overview = {};
  }
  try {
    const r = await sb.rpc('rpc_founder_exit_iv_list', { p_limit: 50 });
    interviews = (r.data as any[]) ?? [];
  } catch {
    interviews = [];
  }
  try {
    const r = await sb.rpc('rpc_founder_exit_iv_by_reason');
    byReason = (r.data as any[]) ?? [];
  } catch {
    byReason = [];
  }
  try {
    const r = await sb.rpc('rpc_founder_exit_iv_tenure_buckets');
    tenureBuckets = (r.data as any[]) ?? [];
  } catch {
    tenureBuckets = [];
  }
  try {
    const r = await sb.rpc('rpc_founder_exit_iv_sentiment');
    sentimentDist = (r.data as any[]) ?? [];
  } catch {
    sentimentDist = [];
  }
  try {
    const r = await sb.rpc('rpc_founder_exit_iv_patterns');
    patterns = (r.data as any[]) ?? [];
  } catch {
    patterns = [];
  }

  const kpis: Kpi[] = [
    { label: 'Total Interviews', value: fmtInt(overview.total_interviews) },
    { label: 'Last 30d', value: fmtInt(overview.last_30d) },
    { label: 'Last 90d', value: fmtInt(overview.last_90d) },
    { label: 'Pending Follow-up', value: fmtInt(overview.pending_followup) },
    { label: 'Rejoin Attempted', value: fmtInt(overview.rejoin_attempted) },
    { label: 'Rejoined', value: fmtInt(overview.rejoined) },
    { label: 'Avg Would-Rejoin', value: fmtNum(overview.avg_rejoin_score) + ' / 10' },
    { label: 'Avg NPS', value: fmtNum(overview.avg_nps, 1) },
    { label: 'Avg Tenure (days)', value: fmtNum(overview.avg_tenure, 1) },
    { label: 'Pay Satisfaction', value: fmtNum(overview.avg_pay_sat) + ' / 5' },
    { label: 'Support Satisfaction', value: fmtNum(overview.avg_support_sat) + ' / 5' },
    { label: 'App Satisfaction', value: fmtNum(overview.avg_app_sat) + ' / 5' },
    { label: 'Negative Sentiment', value: fmtInt(overview.negative_sentiment) },
    { label: 'Positive Sentiment', value: fmtInt(overview.positive_sentiment) },
    { label: 'High Rejoin Promoters', value: fmtInt(overview.high_rejoin_promoters) },
    { label: 'Pay-Reason Exits', value: fmtInt(overview.pay_reason_count) },
  ];

  const interviewCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'interview_date', header: 'Date', render: (r: any) => fmtDate(r.interview_date) },
    { key: 'primary_reason', header: 'Reason', render: (r: any) => r.primary_reason ?? '—' },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => r.sentiment ?? '—' },
    { key: 'would_rejoin_score', header: 'Rejoin', render: (r: any) => fmtInt(r.would_rejoin_score) + ' / 10' },
    { key: 'tenure_days', header: 'Tenure (d)', render: (r: any) => fmtInt(r.tenure_days) },
    { key: 'total_jobs_completed', header: 'Jobs', render: (r: any) => fmtInt(r.total_jobs_completed) },
    { key: 'total_earnings_rupees', header: 'Earnings', render: (r: any) => fmtRupees(r.total_earnings_rupees) },
    { key: 'exit_status', header: 'Status', render: (r: any) => r.exit_status ?? '—' },
  ];

  const reasonCols: Column<any>[] = [
    { key: 'primary_reason', header: 'Reason', render: (r: any) => r.primary_reason ?? '—' },
    { key: 'exit_count', header: 'Exits', render: (r: any) => fmtInt(r.exit_count) },
    { key: 'avg_would_rejoin', header: 'Avg Rejoin', render: (r: any) => fmtNum(r.avg_would_rejoin) },
    { key: 'avg_tenure', header: 'Avg Tenure (d)', render: (r: any) => fmtNum(r.avg_tenure, 1) },
    { key: 'pct_negative', header: '% Negative', render: (r: any) => fmtNum(r.pct_negative, 1) + '%' },
  ];

  const tenureCols: Column<any>[] = [
    { key: 'bucket', header: 'Tenure Bucket', render: (r: any) => r.bucket ?? '—' },
    { key: 'exit_count', header: 'Exits', render: (r: any) => fmtInt(r.exit_count) },
    { key: 'avg_would_rejoin', header: 'Avg Rejoin', render: (r: any) => fmtNum(r.avg_would_rejoin) },
    { key: 'top_reason', header: 'Top Reason', render: (r: any) => r.top_reason ?? '—' },
  ];

  const sentimentCols: Column<any>[] = [
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => r.sentiment ?? '—' },
    { key: 'count_total', header: 'Count', render: (r: any) => fmtInt(r.count_total) },
    { key: 'avg_rejoin', header: 'Avg Rejoin', render: (r: any) => fmtNum(r.avg_rejoin) },
    { key: 'pct', header: '% of Total', render: (r: any) => fmtNum(r.pct, 1) + '%' },
  ];

  const patternCols: Column<any>[] = [
    { key: 'pattern_window', header: 'Window', render: (r: any) => r.pattern_window ?? '—' },
    { key: 'pattern_key', header: 'Key', render: (r: any) => r.pattern_key ?? '—' },
    { key: 'pattern_value', header: 'Value', render: (r: any) => r.pattern_value ?? '—' },
    { key: 'exit_count', header: 'Exits', render: (r: any) => fmtInt(r.exit_count) },
    { key: 'avg_would_rejoin', header: 'Avg Rejoin', render: (r: any) => fmtNum(r.avg_would_rejoin) },
    { key: 'avg_tenure_days', header: 'Avg Tenure', render: (r: any) => fmtNum(r.avg_tenure_days, 1) },
    { key: 'recommended_action', header: 'Recommended Action', render: (r: any) => r.recommended_action ?? '—' },
    { key: 'computed_at', header: 'Computed', render: (r: any) => fmtDate(r.computed_at) },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: 1400, margin: '0 auto', fontFamily: 'system-ui, -apple-system, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <div style={{ fontSize: 12, color: '#666', letterSpacing: 1 }}>FOUNDER CONSOLE • r1619★</div>
        <h1 style={{ margin: '4px 0 6px', fontSize: 26 }}>Engineer Exit Interview Log</h1>
        <p style={{ margin: 0, color: '#555' }}>
          Record exit interview reason, sentiment, would-rejoin score. Aggregate retention patterns.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: 12, marginBottom: 28 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: '12px 14px', background: '#fff' }}>
            <div style={{ fontSize: 11, color: '#777', textTransform: 'uppercase', letterSpacing: 0.5 }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, margin: '0 0 8px' }}>Recent exit interviews</h2>
        <DataTable columns={interviewCols} rows={interviews} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, margin: '0 0 8px' }}>By primary reason</h2>
        <DataTable columns={reasonCols} rows={byReason} rowKey={(r: any) => r.primary_reason} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, margin: '0 0 8px' }}>By tenure bucket</h2>
        <DataTable columns={tenureCols} rows={tenureBuckets} rowKey={(r: any) => r.bucket} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, margin: '0 0 8px' }}>Sentiment distribution</h2>
        <DataTable columns={sentimentCols} rows={sentimentDist} rowKey={(r: any) => r.sentiment} />
      </section>

      <section style={{ marginBottom: 12 }}>
        <h2 style={{ fontSize: 16, margin: '0 0 8px' }}>Retention patterns</h2>
        <DataTable columns={patternCols} rows={patterns} rowKey={(r: any) => r.pattern_window + '/' + r.pattern_key + '/' + r.pattern_value} />
      </section>
    </div>
  );
}
