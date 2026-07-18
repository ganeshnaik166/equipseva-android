import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { pipeline_verdict: string; partnerships: number; pct: number };
type HospRow = {
  anchor_hospital_name: string;
  partnerships: number;
  total_deal_value_rupees: number;
  avg_health_score: number;
  exclusive_deals: number;
  on_track: number;
  at_risk: number;
  won: number;
  lost: number;
};
type MatrixRow = {
  partner_type: string;
  pipeline_stage: string;
  partnerships: number;
  total_deal_value_rupees: number;
  avg_health_score: number;
};
type TrendRow = {
  review_date: string;
  partnerships_reviewed: number;
  avg_health_score: number;
  at_risk_or_critical: number;
  total_deal_value_rupees: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_or_escalated: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type RegRow = {
  regulatory_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  partner_name: string;
  partner_type: string;
  anchor_hospital_name: string;
  pipeline_stage: string;
  health_score: number;
  pipeline_verdict: string;
  next_milestone_type: string;
  next_milestone_date: string | null;
  deal_value_potential_rupees: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3205_verdict_rollup'),
    supabase.rpc('founder_r3205_hospital_scorecard'),
    supabase.rpc('founder_r3205_type_stage_matrix'),
    supabase.rpc('founder_r3205_review_daily_trend'),
    supabase.rpc('founder_r3205_capa_status_board'),
    supabase.rpc('founder_r3205_root_cause_pareto'),
    supabase.rpc('founder_r3205_regulatory_impact_digest'),
    supabase.rpc('founder_r3205_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'pipeline_verdict', header: 'Verdict' },
    { key: 'partnerships', header: 'Partnerships' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'anchor_hospital_name', header: 'Anchor Hospital' },
    { key: 'partnerships', header: 'Deals' },
    { key: 'total_deal_value_rupees', header: 'Deal Value (INR)' },
    { key: 'avg_health_score', header: 'Avg Health' },
    { key: 'exclusive_deals', header: 'Exclusive' },
    { key: 'on_track', header: 'On Track' },
    { key: 'at_risk', header: 'At Risk / Critical' },
    { key: 'won', header: 'Won' },
    { key: 'lost', header: 'Lost' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'partner_type', header: 'Partner Type' },
    { key: 'pipeline_stage', header: 'Stage' },
    { key: 'partnerships', header: 'Deals' },
    { key: 'total_deal_value_rupees', header: 'Deal Value (INR)' },
    { key: 'avg_health_score', header: 'Avg Health' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'review_date', header: 'Review Date' },
    { key: 'partnerships_reviewed', header: 'Reviewed' },
    { key: 'avg_health_score', header: 'Avg Health' },
    { key: 'at_risk_or_critical', header: 'At Risk / Critical' },
    { key: 'total_deal_value_rupees', header: 'Deal Value (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_or_escalated', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Regulatory Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'partner_name', header: 'Partner' },
    { key: 'partner_type', header: 'Type' },
    { key: 'anchor_hospital_name', header: 'Anchor Hospital' },
    { key: 'pipeline_stage', header: 'Stage' },
    { key: 'health_score', header: 'Health' },
    { key: 'pipeline_verdict', header: 'Verdict' },
    { key: 'next_milestone_type', header: 'Next Milestone' },
    { key: 'next_milestone_date', header: 'Milestone Date' },
    { key: 'deal_value_potential_rupees', header: 'Deal Value (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Partnership &amp; Channel-Alliance Pipeline Health Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Partnership pipeline log &mdash; partner type &times; stage &times; deal value &times;
        revenue-share &times; exclusivity &times; health score &amp; CAPA follow-through.
        Founder-gated view: verdict rollups, anchor-hospital scorecards, root-cause pareto,
        and regulatory-impact digest across OEM, distributor, insurer, chain &amp; financing alliances.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Pipeline verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No partnerships logged yet."
          rowKey={(r, i) => String(r.pipeline_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Anchor-hospital scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.anchor_hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Partner type &times; stage matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No deals by type and stage."
          rowKey={(r, i) => `${r.partner_type}-${r.pipeline_stage}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Review-date health trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.review_date ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA findings."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk partnership queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk partnerships."
          rowKey={(r, i) => `${r.partner_name}-${i}`}
        />
      </section>
    </main>
  );
}
