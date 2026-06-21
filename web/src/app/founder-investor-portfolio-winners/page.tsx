import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

type Kpi = { label: string; value: string };

function fmtNum(n: any): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (!isFinite(v)) return '—';
  return v.toLocaleString('en-IN');
}

function fmtPct(n: any): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (!isFinite(v)) return '—';
  return v.toFixed(1) + '%';
}

function fmtDate(v: any): string {
  if (!v) return '—';
  try { return new Date(v).toLocaleDateString('en-IN'); } catch { return '—'; }
}

export default async function FounderInvestorPortfolioWinnersPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let overview: any = null;
  let topWinners: any[] = [];
  let byInvestor: any[] = [];
  let byCategory: any[] = [];
  let recentPitches: any[] = [];
  let outcomes: any[] = [];
  let trend: any[] = [];

  try {
    const r = await sb.rpc('rpc_founder_invwin_overview');
    overview = (r.data && r.data[0]) || null;
  } catch { overview = null; }

  try {
    const r = await sb.rpc('rpc_founder_invwin_top_winners', { p_limit: 25 });
    topWinners = r.data || [];
  } catch { topWinners = []; }

  try {
    const r = await sb.rpc('rpc_founder_invwin_by_investor');
    byInvestor = r.data || [];
  } catch { byInvestor = []; }

  try {
    const r = await sb.rpc('rpc_founder_invwin_by_category');
    byCategory = r.data || [];
  } catch { byCategory = []; }

  try {
    const r = await sb.rpc('rpc_founder_invwin_recent_pitches', { p_limit: 25 });
    recentPitches = r.data || [];
  } catch { recentPitches = []; }

  try {
    const r = await sb.rpc('rpc_founder_invwin_pitch_outcomes');
    outcomes = r.data || [];
  } catch { outcomes = []; }

  try {
    const r = await sb.rpc('rpc_founder_invwin_monthly_trend');
    trend = r.data || [];
  } catch { trend = []; }

  const o = overview || {};

  const kpis: Kpi[] = [
    { label: 'Total Winners', value: fmtNum(o.total_winners) },
    { label: 'Pitch Ready', value: fmtNum(o.pitch_ready_count) },
    { label: 'Archived', value: fmtNum(o.archived_count) },
    { label: 'Investors Covered', value: fmtNum(o.distinct_investors) },
    { label: 'Portfolio Companies', value: fmtNum(o.distinct_companies) },
    { label: 'Revenue Wins', value: fmtNum(o.revenue_wins) },
    { label: 'Customer Wins', value: fmtNum(o.customer_wins) },
    { label: 'Market Moves', value: fmtNum(o.market_moves) },
    { label: 'Exits', value: fmtNum(o.exits) },
    { label: 'Revenue Signal', value: '₹' + fmtNum(o.total_revenue_signal) },
    { label: 'Avg Delta', value: fmtPct(o.avg_delta_pct) },
    { label: 'Max Delta', value: fmtPct(o.max_delta_pct) },
    { label: 'Wins 30d', value: fmtNum(o.last_30d_wins) },
    { label: 'Wins 90d', value: fmtNum(o.last_90d_wins) },
    { label: 'Pitches Used', value: fmtNum(o.pitches_used) },
    { label: 'Positive Outcomes', value: fmtNum(o.positive_outcomes) },
  ];

  const topCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '—' },
    { key: 'portfolio_company', header: 'Company', render: (r: any) => r.portfolio_company ?? '—' },
    { key: 'win_category', header: 'Category', render: (r: any) => r.win_category ?? '—' },
    { key: 'win_headline', header: 'Headline', render: (r: any) => r.win_headline ?? '—' },
    { key: 'win_metric_value', header: 'Metric', render: (r: any) => fmtNum(r.win_metric_value) },
    { key: 'win_metric_delta_pct', header: 'Delta', render: (r: any) => fmtPct(r.win_metric_delta_pct) },
    { key: 'win_observed_at', header: 'Observed', render: (r: any) => fmtDate(r.win_observed_at) },
    { key: 'is_pitch_ready', header: 'Pitch Ready', render: (r: any) => (r.is_pitch_ready ? 'YES' : 'no') },
    { key: 'pitch_rank', header: 'Rank', render: (r: any) => fmtNum(r.pitch_rank) },
  ];

  const investorCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '—' },
    { key: 'win_count', header: 'Wins', render: (r: any) => fmtNum(r.win_count) },
    { key: 'pitch_ready', header: 'Pitch Ready', render: (r: any) => fmtNum(r.pitch_ready) },
    { key: 'total_metric', header: 'Total Metric', render: (r: any) => fmtNum(r.total_metric) },
    { key: 'avg_delta_pct', header: 'Avg Delta', render: (r: any) => fmtPct(r.avg_delta_pct) },
    { key: 'latest_win_at', header: 'Latest Win', render: (r: any) => fmtDate(r.latest_win_at) },
  ];

  const categoryCols: Column<any>[] = [
    { key: 'win_category', header: 'Category', render: (r: any) => r.win_category ?? '—' },
    { key: 'cnt', header: 'Count', render: (r: any) => fmtNum(r.cnt) },
    { key: 'pitch_ready', header: 'Pitch Ready', render: (r: any) => fmtNum(r.pitch_ready) },
    { key: 'avg_delta_pct', header: 'Avg Delta', render: (r: any) => fmtPct(r.avg_delta_pct) },
    { key: 'latest_at', header: 'Latest', render: (r: any) => fmtDate(r.latest_at) },
  ];

  const pitchCols: Column<any>[] = [
    { key: 'pitch_meeting_at', header: 'Meeting', render: (r: any) => fmtDate(r.pitch_meeting_at) },
    { key: 'pitched_to_investor', header: 'Pitched To', render: (r: any) => r.pitched_to_investor ?? '—' },
    { key: 'investor_name', header: 'Source Investor', render: (r: any) => r.investor_name ?? '—' },
    { key: 'win_headline', header: 'Headline', render: (r: any) => r.win_headline ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '—' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'bucket_month', header: 'Month', render: (r: any) => fmtDate(r.bucket_month) },
    { key: 'wins_logged', header: 'Wins Logged', render: (r: any) => fmtNum(r.wins_logged) },
    { key: 'pitch_ready_added', header: 'Pitch Ready', render: (r: any) => fmtNum(r.pitch_ready_added) },
    { key: 'pitches_held', header: 'Pitches Held', render: (r: any) => fmtNum(r.pitches_held) },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>Investor Portfolio Winners</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Showcase top wins from our investor portfolio for founder pitches — per-investor success-story library.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
            <div style={{ fontSize: 12, color: '#6b7280' }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Winners (pitch-ready first)</h2>
        <DataTable columns={topCols} rows={topWinners} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>By Investor</h2>
        <DataTable columns={investorCols} rows={byInvestor} rowKey={(r: any) => r.investor_name} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>By Category</h2>
        <DataTable columns={categoryCols} rows={byCategory} rowKey={(r: any) => r.win_category} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Pitches</h2>
        <DataTable columns={pitchCols} rows={recentPitches} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly Trend (12mo)</h2>
        <DataTable columns={trendCols} rows={trend} rowKey={(r: any) => String(r.bucket_month)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Pitch Outcomes</h2>
        <ul>
          {outcomes.map((o: any) => (
            <li key={o.outcome}>{o.outcome}: {fmtNum(o.cnt)} ({fmtPct(o.pct)})</li>
          ))}
        </ul>
      </section>
    </div>
  );
}
