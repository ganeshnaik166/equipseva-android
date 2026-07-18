import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = {
  verdict: string;
  campaigns: number;
  total_spend: number;
  pct: number;
};
type HospRow = {
  hospital_name: string;
  campaigns: number;
  total_spend: number;
  total_revenue: number;
  customers: number;
  avg_roas: number;
  avg_cac: number;
  avg_ltv_cac: number;
};
type ChannelRow = {
  channel: string;
  campaign_objective: string;
  campaigns: number;
  total_spend: number;
  customers: number;
  avg_roas: number;
};
type TrendRow = {
  period_month: string;
  campaigns: number;
  total_spend: number;
  total_revenue: number;
  customers: number;
  avg_roas: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type RegRow = {
  regulatory_impact: string;
  actions: number;
  open_actions: number;
  total_cost_rupees: number;
};
type RiskRow = {
  hospital_name: string;
  campaign_name: string;
  channel: string;
  period_month: string;
  spend_rupees: number;
  roas: number | null;
  cac_rupees: number | null;
  ltv_cac_ratio: number | null;
  verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    channelRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3177_verdict_rollup'),
    supabase.rpc('founder_r3177_hospital_scorecard'),
    supabase.rpc('founder_r3177_channel_matrix'),
    supabase.rpc('founder_r3177_period_trend'),
    supabase.rpc('founder_r3177_capa_status_board'),
    supabase.rpc('founder_r3177_root_cause_pareto'),
    supabase.rpc('founder_r3177_regulatory_impact_digest'),
    supabase.rpc('founder_r3177_priority_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const channelRows: ChannelRow[] = (channelRes.data as ChannelRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'verdict', header: 'Verdict' },
    { key: 'campaigns', header: 'Campaigns' },
    { key: 'total_spend', header: 'Spend (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital Account' },
    { key: 'campaigns', header: 'Campaigns' },
    { key: 'total_spend', header: 'Spend (INR)' },
    { key: 'total_revenue', header: 'Revenue (INR)' },
    { key: 'customers', header: 'Customers' },
    { key: 'avg_roas', header: 'Avg ROAS' },
    { key: 'avg_cac', header: 'Avg CAC (INR)' },
    { key: 'avg_ltv_cac', header: 'Avg LTV:CAC' },
  ];

  const channelCols: Column<ChannelRow>[] = [
    { key: 'channel', header: 'Channel' },
    { key: 'campaign_objective', header: 'Objective' },
    { key: 'campaigns', header: 'Campaigns' },
    { key: 'total_spend', header: 'Spend (INR)' },
    { key: 'customers', header: 'Customers' },
    { key: 'avg_roas', header: 'Avg ROAS' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'campaigns', header: 'Campaigns' },
    { key: 'total_spend', header: 'Spend (INR)' },
    { key: 'total_revenue', header: 'Revenue (INR)' },
    { key: 'customers', header: 'Customers' },
    { key: 'avg_roas', header: 'Avg ROAS' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Impact' },
    { key: 'actions', header: 'Actions' },
    { key: 'open_actions', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital Account' },
    { key: 'campaign_name', header: 'Campaign' },
    { key: 'channel', header: 'Channel' },
    { key: 'period_month', header: 'Month' },
    { key: 'spend_rupees', header: 'Spend (INR)' },
    { key: 'roas', header: 'ROAS' },
    { key: 'cac_rupees', header: 'CAC (INR)' },
    { key: 'ltv_cac_ratio', header: 'LTV:CAC' },
    { key: 'verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Marketing-Spend ROAS &amp; Channel-CAC Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Per-campaign channel performance — spend &times; leads &times; qualified &times; customers &times;
        revenue attributed &times; CAC &times; ROAS &times; LTV:CAC &amp; optimization CAPA. Founder-gated view:
        verdict rollups, hospital-account scorecards, channel matrix, root-cause pareto, and priority queue
        for campaigns where ROAS &lt; 5 or LTV:CAC &lt; 3.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No campaigns logged yet."
          rowKey={(r, i) => String(r.verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital-account scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No account rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Channel &times; objective matrix</h2>
        <DataTable
          rows={channelRows}
          columns={channelCols}
          emptyMessage="No campaigns by channel."
          rowKey={(r, i) => `${r.channel}-${r.campaign_objective}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly spend &amp; ROAS trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.period_month ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA actions."
          rowKey={(r, i) => String(r.capa_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. Priority queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No priority-queue campaigns."
          rowKey={(r, i) => `${r.campaign_name}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
