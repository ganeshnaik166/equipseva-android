import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  status: string;
  deals: number;
  total_invoice_value_rupees: number;
  pct: number;
};
type ScorecardRow = {
  facility_type: string;
  deals: number;
  total_invoice_value_rupees: number;
  total_advance_rupees: number;
  total_discount_charge_rupees: number;
  avg_advance_rate_pct: number;
  avg_effective_cost_pct: number;
  avg_tenor_days: number;
};
type MatrixRow = {
  facility_type: string;
  status: string;
  deals: number;
  total_invoice_value_rupees: number;
  total_discount_charge_rupees: number;
};
type TrendRow = {
  period_month: string;
  deals: number;
  total_invoice_value_rupees: number;
  total_advance_rupees: number;
  total_discount_charge_rupees: number;
  avg_effective_cost_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  total_impact_rupees: number;
  avg_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impact_rupees: number;
  pct: number;
};
type DigestRow = {
  finding_category: string;
  findings: number;
  open_findings: number;
  total_impact_rupees: number;
  avg_impact_rupees: number;
};
type RiskRow = {
  financier: string;
  deal_ref: string;
  facility_type: string;
  status: string;
  recourse: string;
  period_month: string;
  invoice_value_rupees: number;
  effective_cost_pct: number | null;
  tenor_days: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    scorecardRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3521_status_rollup'),
    supabase.rpc('founder_r3521_facility_type_scorecard'),
    supabase.rpc('founder_r3521_facility_type_status_matrix'),
    supabase.rpc('founder_r3521_monthly_utilization_trend'),
    supabase.rpc('founder_r3521_capa_status_board'),
    supabase.rpc('founder_r3521_root_cause_pareto'),
    supabase.rpc('founder_r3521_cost_impact_digest'),
    supabase.rpc('founder_r3521_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const scorecardRows: ScorecardRow[] = (scorecardRes.data as ScorecardRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'status', header: 'Status' },
    { key: 'deals', header: 'Deals' },
    { key: 'total_invoice_value_rupees', header: 'Invoice Value (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const scorecardCols: Column<ScorecardRow>[] = [
    { key: 'facility_type', header: 'Facility Type' },
    { key: 'deals', header: 'Deals' },
    { key: 'total_invoice_value_rupees', header: 'Invoice Value (INR)' },
    { key: 'total_advance_rupees', header: 'Advance (INR)' },
    { key: 'total_discount_charge_rupees', header: 'Discount Charge (INR)' },
    { key: 'avg_advance_rate_pct', header: 'Avg Advance %' },
    { key: 'avg_effective_cost_pct', header: 'Avg Eff Cost %' },
    { key: 'avg_tenor_days', header: 'Avg Tenor (days)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'facility_type', header: 'Facility Type' },
    { key: 'status', header: 'Status' },
    { key: 'deals', header: 'Deals' },
    { key: 'total_invoice_value_rupees', header: 'Invoice Value (INR)' },
    { key: 'total_discount_charge_rupees', header: 'Discount Charge (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'deals', header: 'Deals' },
    { key: 'total_invoice_value_rupees', header: 'Invoice Value (INR)' },
    { key: 'total_advance_rupees', header: 'Advance (INR)' },
    { key: 'total_discount_charge_rupees', header: 'Discount Charge (INR)' },
    { key: 'avg_effective_cost_pct', header: 'Avg Eff Cost %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'avg_impact_rupees', header: 'Avg Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'finding_category', header: 'Finding Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'avg_impact_rupees', header: 'Avg Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'financier', header: 'Financier' },
    { key: 'deal_ref', header: 'Deal Ref' },
    { key: 'facility_type', header: 'Facility Type' },
    { key: 'status', header: 'Status' },
    { key: 'recourse', header: 'Recourse' },
    { key: 'period_month', header: 'Month' },
    { key: 'invoice_value_rupees', header: 'Invoice Value (INR)' },
    { key: 'effective_cost_pct', header: 'Eff Cost %' },
    { key: 'tenor_days', header: 'Tenor (days)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Trade-Receivables Factoring / Bill-Discounting Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated view of trade-receivables factoring &amp; bill-discounting utilization,
        cost, and recourse risk &mdash; financier &times; facility type (factoring,
        bill-discounting, invoice financing, reverse factoring, TReDS) &times; advance rate
        &times; discount charge &times; effective cost &times; tenor &times; recourse &times;
        settlement status &times; monthly utilization &amp; CAPA closure. Surfaces deals with
        effective cost &gt; 14%, overdue settlements, and recourse-triggered exposure across the
        receivables book.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No factoring deals logged yet."
          rowKey={(r, i) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Facility-type scorecard</h2>
        <DataTable
          rows={scorecardRows}
          columns={scorecardCols}
          emptyMessage="No facility-type rollups."
          rowKey={(r, i) => String(r.facility_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Facility-type &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No deals by facility type."
          rowKey={(r, i) => `${r.facility_type}-${r.status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly utilization trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Cost-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No cost-impact rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk deal queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk deals."
          rowKey={(r, i) => `${r.deal_ref}-${i}`}
        />
      </section>
    </main>
  );
}
