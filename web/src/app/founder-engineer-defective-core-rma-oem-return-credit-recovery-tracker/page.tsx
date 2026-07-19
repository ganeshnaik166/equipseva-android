import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { rma_verdict: string; cases: number; pct: number };
type RegionRow = {
  region: string;
  total_cases: number;
  closed_credited: number;
  awaiting: number;
  overdue: number;
  write_off_risk: number;
  total_part_value_rupees: number;
  total_credit_rupees: number;
  recovery_pct: number;
};
type MatrixRow = {
  equipment_type: string;
  return_reason: string;
  cases: number;
  closed_credited: number;
  avg_part_value_rupees: number;
  total_credit_rupees: number;
};
type TrendRow = {
  rma_raised_date: string;
  cases: number;
  closed_credited: number;
  overdue: number;
  write_off_risk: number;
  part_value_rupees: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_recovery_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_recovery_rupees: number;
  pct: number;
};
type ExposureRow = {
  financial_impact: string;
  findings: number;
  open_findings: number;
  total_recovery_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  region: string;
  rma_code: string;
  oem_vendor: string;
  equipment_type: string;
  return_reason: string;
  rma_raised_date: string;
  days_pending: number;
  aging_bucket: string;
  rma_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    regionRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    exposureRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3328_rma_verdict_rollup'),
    supabase.rpc('founder_r3328_region_scorecard'),
    supabase.rpc('founder_r3328_equipment_reason_matrix'),
    supabase.rpc('founder_r3328_daily_rma_trend'),
    supabase.rpc('founder_r3328_capa_status_board'),
    supabase.rpc('founder_r3328_root_cause_pareto'),
    supabase.rpc('founder_r3328_financial_exposure_digest'),
    supabase.rpc('founder_r3328_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const regionRows: RegionRow[] = (regionRes.data as RegionRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const exposureRows: ExposureRow[] = (exposureRes.data as ExposureRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'rma_verdict', header: 'RMA Verdict' },
    { key: 'cases', header: 'Cases' },
    { key: 'pct', header: 'Share %' },
  ];

  const regionCols: Column<RegionRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'total_cases', header: 'Cases' },
    { key: 'closed_credited', header: 'Closed / Credited' },
    { key: 'awaiting', header: 'Awaiting / In-Transit' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'write_off_risk', header: 'Write-Off Risk' },
    { key: 'total_part_value_rupees', header: 'Part Value (INR)' },
    { key: 'total_credit_rupees', header: 'Credit Recovered (INR)' },
    { key: 'recovery_pct', header: 'Recovery %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'equipment_type', header: 'Equipment Type' },
    { key: 'return_reason', header: 'Return Reason' },
    { key: 'cases', header: 'Cases' },
    { key: 'closed_credited', header: 'Closed / Credited' },
    { key: 'avg_part_value_rupees', header: 'Avg Part Value (INR)' },
    { key: 'total_credit_rupees', header: 'Credit Recovered (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'rma_raised_date', header: 'RMA Raised' },
    { key: 'cases', header: 'Cases' },
    { key: 'closed_credited', header: 'Closed / Credited' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'write_off_risk', header: 'Write-Off Risk' },
    { key: 'part_value_rupees', header: 'Part Value (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_recovery_rupees', header: 'Avg Recovery (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_recovery_rupees', header: 'Recovery at Stake (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const exposureCols: Column<ExposureRow>[] = [
    { key: 'financial_impact', header: 'Financial Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_recovery_rupees', header: 'Recovery Amount (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'region', header: 'Region' },
    { key: 'rma_code', header: 'RMA Code' },
    { key: 'oem_vendor', header: 'OEM Vendor' },
    { key: 'equipment_type', header: 'Equipment' },
    { key: 'return_reason', header: 'Return Reason' },
    { key: 'rma_raised_date', header: 'Raised' },
    { key: 'days_pending', header: 'Days Pending' },
    { key: 'aging_bucket', header: 'Aging' },
    { key: 'rma_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Defective-Core / Faulty-Part RMA-to-OEM Return &amp; Credit-Recovery Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Reverse-logistics ledger — equipment type &times; return reason &times; OEM vendor &times;
        aging bucket &times; credit recovery &amp; CAPA closure. When a warranty part or exchange-core
        is replaced, the faulty unit must be returned to the OEM for credit or core-exchange; failure
        to return means direct financial loss. Founder-gated view: RMA verdicts, region recovery
        scorecards, root-cause pareto, and financial-exposure digest across overdue &amp; write-off-risk cases.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. RMA verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No RMA cases logged yet."
          rowKey={(r, i) => String(r.rma_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Region credit-recovery scorecard</h2>
        <DataTable
          rows={regionRows}
          columns={regionCols}
          emptyMessage="No region rollups."
          rowKey={(r, i) => String(r.region ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Equipment type &times; return reason matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No cases by equipment / reason."
          rowKey={(r, i) => `${r.equipment_type}-${r.return_reason}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily RMA-raised trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.rma_raised_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Financial-exposure digest</h2>
        <DataTable
          rows={exposureRows}
          columns={exposureCols}
          emptyMessage="No financial-impact rollups."
          rowKey={(r, i) => String(r.financial_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk RMA queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk RMA cases."
          rowKey={(r, i) => `${r.rma_code}-${i}`}
        />
      </section>
    </main>
  );
}
