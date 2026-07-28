import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { contract_status: string; contracts: number; pct: number };
type OemRow = {
  oem_name: string;
  contracts: number;
  fully_aligned: number;
  major_gap: number;
  uncovered: number;
  negative_margin: number;
  avg_margin_pct: number;
  avg_sla_gap_hrs: number;
};
type MatrixRow = {
  coverage_alignment: string;
  contract_status: string;
  contracts: number;
  avg_margin_pct: number;
  avg_sla_gap_hrs: number;
};
type TrendRow = {
  period_month: string;
  contracts: number;
  total_customer_price_rupees: number;
  total_oem_cost_rupees: number;
  avg_margin_pct: number;
  negative_margin: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
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
  coverage_alignment: string;
  contracts: number;
  avg_sla_gap_hrs: number;
  max_sla_gap_hrs: number;
  total_customer_price_rupees: number;
  total_oem_cost_rupees: number;
  avg_margin_pct: number;
};
type RiskRow = {
  customer_name: string;
  contract_code: string;
  device_model: string;
  oem_name: string;
  period_month: string;
  coverage_alignment: string;
  contract_status: string;
  sla_gap_hrs: number;
  margin_pct: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    oemRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3572_contract_status_rollup'),
    supabase.rpc('founder_r3572_oem_scorecard'),
    supabase.rpc('founder_r3572_coverage_status_matrix'),
    supabase.rpc('founder_r3572_monthly_margin_trend'),
    supabase.rpc('founder_r3572_capa_status_board'),
    supabase.rpc('founder_r3572_root_cause_pareto'),
    supabase.rpc('founder_r3572_sla_gap_impact_digest'),
    supabase.rpc('founder_r3572_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const oemRows: OemRow[] = (oemRes.data as OemRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'contract_status', header: 'Contract Status' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'pct', header: 'Share %' },
  ];

  const oemCols: Column<OemRow>[] = [
    { key: 'oem_name', header: 'OEM' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'fully_aligned', header: 'Fully Aligned' },
    { key: 'major_gap', header: 'Major Gap' },
    { key: 'uncovered', header: 'Uncovered' },
    { key: 'negative_margin', header: 'Neg Margin' },
    { key: 'avg_margin_pct', header: 'Avg Margin %' },
    { key: 'avg_sla_gap_hrs', header: 'Avg SLA Gap Hrs' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'coverage_alignment', header: 'Coverage Alignment' },
    { key: 'contract_status', header: 'Contract Status' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'avg_margin_pct', header: 'Avg Margin %' },
    { key: 'avg_sla_gap_hrs', header: 'Avg SLA Gap Hrs' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'total_customer_price_rupees', header: 'Customer Price (INR)' },
    { key: 'total_oem_cost_rupees', header: 'OEM Cost (INR)' },
    { key: 'avg_margin_pct', header: 'Avg Margin %' },
    { key: 'negative_margin', header: 'Neg Margin' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
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
    { key: 'coverage_alignment', header: 'Coverage Alignment' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'avg_sla_gap_hrs', header: 'Avg SLA Gap Hrs' },
    { key: 'max_sla_gap_hrs', header: 'Max SLA Gap Hrs' },
    { key: 'total_customer_price_rupees', header: 'Customer Price (INR)' },
    { key: 'total_oem_cost_rupees', header: 'OEM Cost (INR)' },
    { key: 'avg_margin_pct', header: 'Avg Margin %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'customer_name', header: 'Customer' },
    { key: 'contract_code', header: 'Contract' },
    { key: 'device_model', header: 'Device' },
    { key: 'oem_name', header: 'OEM' },
    { key: 'period_month', header: 'Month' },
    { key: 'coverage_alignment', header: 'Coverage' },
    { key: 'contract_status', header: 'Status' },
    { key: 'sla_gap_hrs', header: 'SLA Gap Hrs' },
    { key: 'margin_pct', header: 'Margin %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer OEM Service-Contract Back-to-Back SLA / Margin Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Back-to-back OEM service-contract ledger &mdash; where we resell OEM support to hospitals, this
        view aligns the customer-facing SLA against the OEM&apos;s SLA and tracks resale margin. Contract
        status &times; coverage alignment (fully aligned, minor/major gap, uncovered, over-covered)
        &times; SLA-gap hours &times; customer price vs OEM cost &times; margin % &amp; CAPA closure.
        Founder-gated view: status rollups, OEM scorecards, root-cause pareto, SLA-gap impact digest, and
        the high-risk queue where OEM SLA is slower than the customer commit, scope is uncovered, or
        margin has turned negative.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Contract status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No contracts logged yet."
          rowKey={(r, i) => String(r.contract_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. OEM scorecard</h2>
        <DataTable
          rows={oemRows}
          columns={oemCols}
          emptyMessage="No OEM rollups."
          rowKey={(r, i) => String(r.oem_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Coverage alignment &times; contract status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No contracts by coverage alignment."
          rowKey={(r, i) => `${r.coverage_alignment}-${r.contract_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly margin trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. SLA-gap impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No SLA-gap digest data."
          rowKey={(r, i) => String(r.coverage_alignment ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk contract queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk contracts."
          rowKey={(r, i) => `${r.contract_code}-${i}`}
        />
      </section>
    </main>
  );
}
