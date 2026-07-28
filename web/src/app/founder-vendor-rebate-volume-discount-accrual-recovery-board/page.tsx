import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { recovery_status: string; programs: number; total_gap_rupees: number; pct: number };
type TypeRow = {
  rebate_type: string;
  programs: number;
  total_ytd_purchase_rupees: number;
  total_earned_rupees: number;
  total_accrued_rupees: number;
  total_received_rupees: number;
  total_gap_rupees: number;
  avg_attainment_pct: number;
  shortfall_count: number;
};
type MatrixRow = {
  rebate_type: string;
  recovery_status: string;
  programs: number;
  total_gap_rupees: number;
  avg_attainment_pct: number;
};
type TrendRow = {
  period_month: string;
  programs: number;
  total_accrued_rupees: number;
  total_received_rupees: number;
  total_gap_rupees: number;
  avg_attainment_pct: number;
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
type DigestRow = {
  supplier_name: string;
  programs: number;
  total_earned_rupees: number;
  total_received_rupees: number;
  total_gap_rupees: number;
  avg_attainment_pct: number;
};
type RiskRow = {
  supplier_name: string;
  program_code: string;
  rebate_program: string;
  rebate_type: string;
  period_month: string | null;
  recovery_status: string;
  ytd_purchase_rupees: number | null;
  threshold_rupees: number | null;
  gap_rupees: number | null;
  attainment_pct: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    typeRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3517_recovery_status_rollup'),
    supabase.rpc('founder_r3517_rebate_type_scorecard'),
    supabase.rpc('founder_r3517_rebate_type_recovery_matrix'),
    supabase.rpc('founder_r3517_monthly_accrual_trend'),
    supabase.rpc('founder_r3517_capa_status_board'),
    supabase.rpc('founder_r3517_root_cause_pareto'),
    supabase.rpc('founder_r3517_rebate_gap_impact_digest'),
    supabase.rpc('founder_r3517_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const typeRows: TypeRow[] = (typeRes.data as TypeRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'recovery_status', header: 'Recovery Status' },
    { key: 'programs', header: 'Programs' },
    { key: 'total_gap_rupees', header: 'Total Gap (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const typeCols: Column<TypeRow>[] = [
    { key: 'rebate_type', header: 'Rebate Type' },
    { key: 'programs', header: 'Programs' },
    { key: 'total_ytd_purchase_rupees', header: 'YTD Purchase (INR)' },
    { key: 'total_earned_rupees', header: 'Earned (INR)' },
    { key: 'total_accrued_rupees', header: 'Accrued (INR)' },
    { key: 'total_received_rupees', header: 'Received (INR)' },
    { key: 'total_gap_rupees', header: 'Gap (INR)' },
    { key: 'avg_attainment_pct', header: 'Avg Attainment %' },
    { key: 'shortfall_count', header: 'At-Risk / Shortfall' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'rebate_type', header: 'Rebate Type' },
    { key: 'recovery_status', header: 'Recovery Status' },
    { key: 'programs', header: 'Programs' },
    { key: 'total_gap_rupees', header: 'Gap (INR)' },
    { key: 'avg_attainment_pct', header: 'Avg Attainment %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'programs', header: 'Programs' },
    { key: 'total_accrued_rupees', header: 'Accrued (INR)' },
    { key: 'total_received_rupees', header: 'Received (INR)' },
    { key: 'total_gap_rupees', header: 'Gap (INR)' },
    { key: 'avg_attainment_pct', header: 'Avg Attainment %' },
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
    { key: 'total_recovery_rupees', header: 'Recovery Value (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'supplier_name', header: 'Supplier' },
    { key: 'programs', header: 'Programs' },
    { key: 'total_earned_rupees', header: 'Earned (INR)' },
    { key: 'total_received_rupees', header: 'Received (INR)' },
    { key: 'total_gap_rupees', header: 'Gap (INR)' },
    { key: 'avg_attainment_pct', header: 'Avg Attainment %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'supplier_name', header: 'Supplier' },
    { key: 'program_code', header: 'Program' },
    { key: 'rebate_program', header: 'Scheme' },
    { key: 'rebate_type', header: 'Type' },
    { key: 'period_month', header: 'Period' },
    { key: 'recovery_status', header: 'Status' },
    { key: 'ytd_purchase_rupees', header: 'YTD Purchase (INR)' },
    { key: 'threshold_rupees', header: 'Threshold (INR)' },
    { key: 'gap_rupees', header: 'Gap (INR)' },
    { key: 'attainment_pct', header: 'Attainment %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Vendor-Rebate / Volume-Discount Accrual &amp; Recovery Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated view of vendor rebate &amp; volume-discount accrual versus what is actually
        earned and recovered per supplier tier &mdash; rebate type (volume tier, early payment,
        loyalty, growth, marketing co-op, mix) &times; recovery status &times; YTD purchase &times;
        threshold &times; earned / accrued / received &times; gap &times; attainment %. Tracks
        recovery-status distribution, rebate-type scorecards, root-cause pareto, and the rebate-gap
        impact digest so shortfalls &amp; disputes are chased before they lapse.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Recovery-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No rebate programs logged yet."
          rowKey={(r, i) => String(r.recovery_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Rebate-type scorecard</h2>
        <DataTable
          rows={typeRows}
          columns={typeCols}
          emptyMessage="No rebate-type rollups."
          rowKey={(r, i) => String(r.rebate_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Rebate-type &times; recovery-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.rebate_type}-${r.recovery_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly accrual trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Rebate-gap impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No supplier gap rollups."
          rowKey={(r, i) => String(r.supplier_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk recovery queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk programs."
          rowKey={(r, i) => `${r.program_code}-${i}`}
        />
      </section>
    </main>
  );
}
