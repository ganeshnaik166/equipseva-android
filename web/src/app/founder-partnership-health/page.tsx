import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type PortfolioRow = {
  total_partnerships: number | null;
  healthy_count: number | null;
  watch_count: number | null;
  at_risk_count: number | null;
  critical_count: number | null;
  avg_composite: number | null;
  touchpoints_last_30d: number | null;
};

type ListRow = {
  partnership_org_id: string;
  org_name: string | null;
  state: string | null;
  composite_score: number | null;
  touchpoint_score: number | null;
  revenue_score: number | null;
  sentiment_score: number | null;
  risk_band: string | null;
  last_touchpoint_at: string | null;
  scored_at: string | null;
};

type AtRiskRow = {
  partnership_org_id: string;
  org_name: string | null;
  state: string | null;
  composite_score: number | null;
  risk_band: string | null;
  days_since_touchpoint: number | null;
  revenue_last_90d_rupees: number | null;
  scored_at: string | null;
};

type TouchpointRow = {
  id: string;
  partnership_org_id: string;
  org_name: string | null;
  touchpoint_kind: string | null;
  sentiment: string | null;
  notes: string | null;
  touchpoint_at: string | null;
};

type SentimentRow = { sentiment: string | null; touchpoint_count: number | null; pct: number | null };
type RevScoreRow = {
  partnership_org_id: string;
  org_name: string | null;
  composite_score: number | null;
  revenue_last_90d_rupees: number | null;
  amc_active_count: number | null;
};
type CadenceRow = { bucket_label: string | null; partnership_count: number | null };

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return '—';
  return `₹${Number(n).toLocaleString('en-IN')}`;
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '—';
  try { return new Date(s).toLocaleString('en-IN'); } catch { return '—'; }
}

export default async function FounderPartnershipHealthPage() {
  const sb = await getSupabaseServerClient();

  const portfolioRes = await sb.rpc('founder_partnership_health_portfolio');
  const listRes = await sb.rpc('founder_partnership_health_list');
  const atRiskRes = await sb.rpc('founder_partnership_health_at_risk');
  const recentRes = await sb.rpc('founder_partnership_health_recent_touchpoints');
  const sentimentRes = await sb.rpc('founder_partnership_health_sentiment_mix');
  const revScoreRes = await sb.rpc('founder_partnership_health_revenue_vs_score');
  const cadenceRes = await sb.rpc('founder_partnership_health_cadence_stats');

  const portfolio: PortfolioRow = (portfolioRes.data?.[0] as PortfolioRow) ?? {
    total_partnerships: 0,
    healthy_count: 0,
    watch_count: 0,
    at_risk_count: 0,
    critical_count: 0,
    avg_composite: 0,
    touchpoints_last_30d: 0,
  };
  const list: ListRow[] = (listRes.data as ListRow[]) ?? [];
  const atRisk: AtRiskRow[] = (atRiskRes.data as AtRiskRow[]) ?? [];
  const recent: TouchpointRow[] = (recentRes.data as TouchpointRow[]) ?? [];
  const sentiment: SentimentRow[] = (sentimentRes.data as SentimentRow[]) ?? [];
  const revScore: RevScoreRow[] = (revScoreRes.data as RevScoreRow[]) ?? [];
  const cadence: CadenceRow[] = (cadenceRes.data as CadenceRow[]) ?? [];

  const listCols: Column<ListRow>[] = [
    { key: 'org_name', header: 'Partnership', render: (r) => r.org_name ?? '—' },
    { key: 'state', header: 'State', render: (r) => r.state ?? '—' },
    { key: 'composite_score', header: 'Composite', render: (r) => String(r.composite_score ?? '—') },
    { key: 'touchpoint_score', header: 'Touch', render: (r) => String(r.touchpoint_score ?? '—') },
    { key: 'revenue_score', header: 'Revenue', render: (r) => String(r.revenue_score ?? '—') },
    { key: 'sentiment_score', header: 'Sentiment', render: (r) => String(r.sentiment_score ?? '—') },
    { key: 'risk_band', header: 'Band', render: (r) => r.risk_band ?? '—' },
    { key: 'last_touchpoint_at', header: 'Last touch', render: (r) => fmtDate(r.last_touchpoint_at) },
    { key: 'scored_at', header: 'Scored', render: (r) => fmtDate(r.scored_at) },
  ];

  const atRiskCols: Column<AtRiskRow>[] = [
    { key: 'org_name', header: 'Partnership', render: (r) => r.org_name ?? '—' },
    { key: 'state', header: 'State', render: (r) => r.state ?? '—' },
    { key: 'composite_score', header: 'Composite', render: (r) => String(r.composite_score ?? '—') },
    { key: 'risk_band', header: 'Band', render: (r) => r.risk_band ?? '—' },
    { key: 'days_since_touchpoint', header: 'Days silent', render: (r) => String(r.days_since_touchpoint ?? '—') },
    { key: 'revenue_last_90d_rupees', header: 'Rev 90d', render: (r) => fmtRupees(r.revenue_last_90d_rupees) },
    { key: 'scored_at', header: 'Scored', render: (r) => fmtDate(r.scored_at) },
  ];

  const recentCols: Column<TouchpointRow>[] = [
    { key: 'touchpoint_at', header: 'When', render: (r) => fmtDate(r.touchpoint_at) },
    { key: 'org_name', header: 'Partnership', render: (r) => r.org_name ?? '—' },
    { key: 'touchpoint_kind', header: 'Kind', render: (r) => r.touchpoint_kind ?? '—' },
    { key: 'sentiment', header: 'Sentiment', render: (r) => r.sentiment ?? '—' },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '—' },
  ];

  const sentimentCols: Column<SentimentRow>[] = [
    { key: 'sentiment', header: 'Sentiment', render: (r) => r.sentiment ?? '—' },
    { key: 'touchpoint_count', header: 'Count', render: (r) => String(r.touchpoint_count ?? '—') },
    { key: 'pct', header: 'Share %', render: (r) => (r.pct == null ? '—' : `${r.pct}%`) },
  ];

  const revScoreCols: Column<RevScoreRow>[] = [
    { key: 'org_name', header: 'Partnership', render: (r) => r.org_name ?? '—' },
    { key: 'composite_score', header: 'Composite', render: (r) => String(r.composite_score ?? '—') },
    { key: 'revenue_last_90d_rupees', header: 'Rev 90d', render: (r) => fmtRupees(r.revenue_last_90d_rupees) },
    { key: 'amc_active_count', header: 'AMC active', render: (r) => String(r.amc_active_count ?? '—') },
  ];

  const cadenceCols: Column<CadenceRow>[] = [
    { key: 'bucket_label', header: 'Last touch bucket', render: (r) => r.bucket_label ?? '—' },
    { key: 'partnership_count', header: 'Partnerships', render: (r) => String(r.partnership_count ?? '—') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 4 }}>Founder · Partnership Health Monitor</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Composite health-score per partnership: touchpoint cadence + revenue delivered + relationship sentiment.
        At-risk surface drives founder outreach. (r1642 · extends r1456)
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Total partnerships</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{portfolio.total_partnerships ?? '—'}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Healthy</div>
          <div style={{ fontSize: 22, fontWeight: 700, color: '#0a7d2c' }}>{portfolio.healthy_count ?? '—'}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Watch</div>
          <div style={{ fontSize: 22, fontWeight: 700, color: '#a67b00' }}>{portfolio.watch_count ?? '—'}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>At-risk</div>
          <div style={{ fontSize: 22, fontWeight: 700, color: '#c0392b' }}>{portfolio.at_risk_count ?? '—'}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Critical</div>
          <div style={{ fontSize: 22, fontWeight: 700, color: '#7a0f00' }}>{portfolio.critical_count ?? '—'}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Avg composite</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{portfolio.avg_composite ?? '—'}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Touchpoints (30d)</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{portfolio.touchpoints_last_30d ?? '—'}</div>
        </div>
      </section>

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '12px 0' }}>At-risk partnerships</h2>
      <DataTable
        rows={atRisk}
        columns={atRiskCols}
        rowKey={(r: any, i: number) => String(r.id ?? r.partnership_org_id ?? i)}
      />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 12px' }}>All partnerships · latest score</h2>
      <DataTable
        rows={list}
        columns={listCols}
        rowKey={(r: any, i: number) => String(r.id ?? r.partnership_org_id ?? i)}
      />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 12px' }}>Recent touchpoints</h2>
      <DataTable
        rows={recent}
        columns={recentCols}
        rowKey={(r: any, i: number) => String(r.id ?? i)}
      />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 12px' }}>Sentiment mix (90d)</h2>
      <DataTable
        rows={sentiment}
        columns={sentimentCols}
        rowKey={(r: any, i: number) => String(r.id ?? r.sentiment ?? i)}
      />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 12px' }}>Revenue vs score</h2>
      <DataTable
        rows={revScore}
        columns={revScoreCols}
        rowKey={(r: any, i: number) => String(r.id ?? r.partnership_org_id ?? i)}
      />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 12px' }}>Touchpoint cadence</h2>
      <DataTable
        rows={cadence}
        columns={cadenceCols}
        rowKey={(r: any, i: number) => String(r.id ?? r.bucket_label ?? i)}
      />
    </main>
  );
}
