import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  profitability_status: string;
  accounts: number;
  total_revenue_rupees: number;
  total_net_contribution_rupees: number;
  pct: number;
};
type SegmentRow = {
  segment: string;
  accounts: number;
  total_revenue_rupees: number;
  total_cogs_rupees: number;
  total_net_contribution_rupees: number;
  avg_gross_margin_pct: number;
  avg_contribution_margin_pct: number;
  loss_making: number;
};
type MatrixRow = {
  segment: string;
  profitability_status: string;
  accounts: number;
  total_net_contribution_rupees: number;
  avg_contribution_margin_pct: number;
};
type TrendRow = {
  period_month: string;
  accounts: number;
  total_revenue_rupees: number;
  total_net_contribution_rupees: number;
  avg_contribution_margin_pct: number;
  loss_making: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  total_margin_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_margin_impact_rupees: number;
  pct: number;
};
type ImpactRow = {
  impact_category: string;
  findings: number;
  open_findings: number;
  total_margin_impact_rupees: number;
};
type RiskRow = {
  customer_name: string;
  account_code: string;
  segment: string;
  period_month: string;
  profitability_status: string;
  gross_margin_pct: number;
  contribution_margin_pct: number;
  net_contribution_rupees: number;
  cost_to_serve_rupees: number;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    segmentRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3598_profitability_status_rollup'),
    supabase.rpc('founder_r3598_segment_scorecard'),
    supabase.rpc('founder_r3598_segment_status_matrix'),
    supabase.rpc('founder_r3598_monthly_contribution_trend'),
    supabase.rpc('founder_r3598_capa_status_board'),
    supabase.rpc('founder_r3598_root_cause_pareto'),
    supabase.rpc('founder_r3598_margin_impact_digest'),
    supabase.rpc('founder_r3598_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const segmentRows: SegmentRow[] = (segmentRes.data as SegmentRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'profitability_status', header: 'Profitability Status' },
    { key: 'accounts', header: 'Accounts' },
    { key: 'total_revenue_rupees', header: 'Revenue (INR)' },
    { key: 'total_net_contribution_rupees', header: 'Net Contribution (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const segmentCols: Column<SegmentRow>[] = [
    { key: 'segment', header: 'Segment' },
    { key: 'accounts', header: 'Accounts' },
    { key: 'total_revenue_rupees', header: 'Revenue (INR)' },
    { key: 'total_cogs_rupees', header: 'COGS (INR)' },
    { key: 'total_net_contribution_rupees', header: 'Net Contribution (INR)' },
    { key: 'avg_gross_margin_pct', header: 'Avg GM %' },
    { key: 'avg_contribution_margin_pct', header: 'Avg CM %' },
    { key: 'loss_making', header: 'Loss-Making' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'segment', header: 'Segment' },
    { key: 'profitability_status', header: 'Profitability Status' },
    { key: 'accounts', header: 'Accounts' },
    { key: 'total_net_contribution_rupees', header: 'Net Contribution (INR)' },
    { key: 'avg_contribution_margin_pct', header: 'Avg CM %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'accounts', header: 'Accounts' },
    { key: 'total_revenue_rupees', header: 'Revenue (INR)' },
    { key: 'total_net_contribution_rupees', header: 'Net Contribution (INR)' },
    { key: 'avg_contribution_margin_pct', header: 'Avg CM %' },
    { key: 'loss_making', header: 'Loss-Making' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'total_margin_impact_rupees', header: 'Margin Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_margin_impact_rupees', header: 'Margin Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'impact_category', header: 'Impact Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_margin_impact_rupees', header: 'Margin Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'customer_name', header: 'Customer' },
    { key: 'account_code', header: 'Account' },
    { key: 'segment', header: 'Segment' },
    { key: 'period_month', header: 'Month' },
    { key: 'profitability_status', header: 'Status' },
    { key: 'gross_margin_pct', header: 'GM %' },
    { key: 'contribution_margin_pct', header: 'CM %' },
    { key: 'net_contribution_rupees', header: 'Net Contribution (INR)' },
    { key: 'cost_to_serve_rupees', header: 'Cost-to-Serve (INR)' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer-Account Profitability P&amp;L / Margin Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Per-customer/account profitability P&amp;L &mdash; segment (AMC services, spare parts,
        projects, diagnostics, rentals) &times; period &times; revenue &times; COGS &times; gross
        margin &times; service cost &times; allocated overhead &times; net contribution &times;
        contribution margin &times; cost-to-serve &amp; margin-recovery CAPA closure. Founder-gated
        view: profitability-status distribution, segment scorecards, segment &times; status matrix,
        monthly contribution trend, root-cause pareto, and margin-impact digest across loss-making
        &amp; marginal accounts.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Profitability status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No account P&amp;L rows logged yet."
          rowKey={(r, i) => String(r.profitability_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Segment scorecard</h2>
        <DataTable
          rows={segmentRows}
          columns={segmentCols}
          emptyMessage="No segment rollups."
          rowKey={(r, i) => String(r.segment ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Segment &times; profitability-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No accounts by segment."
          rowKey={(r, i) => `${r.segment}-${r.profitability_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly contribution trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Margin-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No margin-impact rollups."
          rowKey={(r, i) => String(r.impact_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk account queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk accounts."
          rowKey={(r, i) => `${r.account_code}-${i}`}
        />
      </section>
    </main>
  );
}
