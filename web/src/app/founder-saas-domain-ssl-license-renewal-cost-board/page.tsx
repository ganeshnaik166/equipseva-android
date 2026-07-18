import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type DecisionRow = {
  renewal_decision: string;
  assets: number;
  total_annual_cost_rupees: number;
  pct: number;
};
type TeamRow = {
  owner_team: string;
  total_assets: number;
  business_critical: number;
  auto_renew_on: number;
  low_utilization: number;
  cancel_or_downgrade: number;
  avg_utilization_pct: number;
  total_annual_cost_rupees: number;
};
type MatrixRow = {
  asset_type: string;
  billing_cycle: string;
  assets: number;
  total_annual_cost_rupees: number;
  avg_utilization_pct: number;
  auto_renew_on: number;
};
type TrendRow = {
  renewal_date: string;
  assets: number;
  total_annual_cost_rupees: number;
  auto_renew_on: number;
  business_critical: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_savings_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_savings_rupees: number;
  pct: number;
};
type ImpactRow = {
  cost_impact: string;
  findings: number;
  open_findings: number;
  total_savings_rupees: number;
};
type RiskRow = {
  asset_name: string;
  asset_type: string;
  vendor: string;
  owner_team: string;
  renewal_date: string;
  annual_cost_rupees: number;
  utilization_pct: number | null;
  renewal_decision: string;
  criticality: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    decisionRes,
    teamRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3245_renewal_decision_rollup'),
    supabase.rpc('founder_r3245_owner_team_scorecard'),
    supabase.rpc('founder_r3245_asset_type_billing_matrix'),
    supabase.rpc('founder_r3245_renewal_date_trend'),
    supabase.rpc('founder_r3245_capa_status_board'),
    supabase.rpc('founder_r3245_root_cause_pareto'),
    supabase.rpc('founder_r3245_cost_impact_digest'),
    supabase.rpc('founder_r3245_high_risk_queue'),
  ]);

  const decisionRows: DecisionRow[] = (decisionRes.data as DecisionRow[]) ?? [];
  const teamRows: TeamRow[] = (teamRes.data as TeamRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const decisionCols: Column<DecisionRow>[] = [
    { key: 'renewal_decision', header: 'Renewal Decision' },
    { key: 'assets', header: 'Assets' },
    { key: 'total_annual_cost_rupees', header: 'Total Annual Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const teamCols: Column<TeamRow>[] = [
    { key: 'owner_team', header: 'Owner Team' },
    { key: 'total_assets', header: 'Assets' },
    { key: 'business_critical', header: 'Business-Critical' },
    { key: 'auto_renew_on', header: 'Auto-Renew On' },
    { key: 'low_utilization', header: 'Utilization Below 50%' },
    { key: 'cancel_or_downgrade', header: 'Cancel / Downgrade' },
    { key: 'avg_utilization_pct', header: 'Avg Utilization %' },
    { key: 'total_annual_cost_rupees', header: 'Total Annual Cost (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'asset_type', header: 'Asset Type' },
    { key: 'billing_cycle', header: 'Billing Cycle' },
    { key: 'assets', header: 'Assets' },
    { key: 'total_annual_cost_rupees', header: 'Total Annual Cost (INR)' },
    { key: 'avg_utilization_pct', header: 'Avg Utilization %' },
    { key: 'auto_renew_on', header: 'Auto-Renew On' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'renewal_date', header: 'Renewal Date' },
    { key: 'assets', header: 'Assets' },
    { key: 'total_annual_cost_rupees', header: 'Total Annual Cost (INR)' },
    { key: 'auto_renew_on', header: 'Auto-Renew On' },
    { key: 'business_critical', header: 'Business-Critical' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_savings_rupees', header: 'Avg Savings (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_savings_rupees', header: 'Total Savings (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'cost_impact', header: 'Cost Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_savings_rupees', header: 'Total Savings (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'asset_name', header: 'Asset' },
    { key: 'asset_type', header: 'Type' },
    { key: 'vendor', header: 'Vendor' },
    { key: 'owner_team', header: 'Owner Team' },
    { key: 'renewal_date', header: 'Renewal Date' },
    { key: 'annual_cost_rupees', header: 'Annual Cost (INR)' },
    { key: 'utilization_pct', header: 'Utilization %' },
    { key: 'renewal_decision', header: 'Decision' },
    { key: 'criticality', header: 'Criticality' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder SaaS, Domain, SSL &amp; Software-License Renewal Cost Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder business governance — asset type &times; vendor &times; owner team &times; billing
        cycle &times; seats &times; annual cost &times; renewal date &times; auto-renew &times;
        utilization &amp; renewal decision. Founder-gated view: decision rollups, team spend
        scorecards, renewal-date load, root-cause pareto, and cost-impact digest across SaaS
        subscriptions, domains, SSL certificates, software licenses &amp; API plans.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Renewal decision distribution</h2>
        <DataTable
          rows={decisionRows}
          columns={decisionCols}
          emptyMessage="No subscriptions or assets logged yet."
          rowKey={(r, i) => String(r.renewal_decision ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Owner-team spend scorecard</h2>
        <DataTable
          rows={teamRows}
          columns={teamCols}
          emptyMessage="No team rollups."
          rowKey={(r, i) => String(r.owner_team ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Asset type &times; billing cycle matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No assets by type."
          rowKey={(r, i) => `${r.asset_type}-${r.billing_cycle}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Renewal date load</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No renewal dates."
          rowKey={(r, i) => String(r.renewal_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Cost impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No cost-impact rollups."
          rowKey={(r, i) => String(r.cost_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk renewal queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk assets."
          rowKey={(r, i) => `${r.asset_name}-${r.renewal_date}-${i}`}
        />
      </section>
    </main>
  );
}
