import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  recon_status: string;
  entries: number;
  total_unmatched_rupees: number;
  pct: number;
};
type UnitPairRow = {
  unit_pair: string;
  entries: number;
  total_receivable_rupees: number;
  total_payable_rupees: number;
  total_difference_rupees: number;
  total_unmatched_rupees: number;
  avg_matched_pct: number;
  unreconciled: number;
};
type MatrixRow = {
  unit_pair: string;
  recon_status: string;
  entries: number;
  total_unmatched_rupees: number;
  avg_ageing_days: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  total_difference_rupees: number;
  total_unmatched_rupees: number;
  avg_matched_pct: number;
  material_or_unreconciled: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  total_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impact_rupees: number;
  pct: number;
};
type DigestRow = {
  recon_status: string;
  entries: number;
  total_unmatched_rupees: number;
  total_difference_rupees: number;
  avg_ageing_days: number;
};
type RiskRow = {
  unit_pair: string;
  recon_ref: string;
  period_month: string;
  recon_status: string;
  difference_rupees: number;
  unmatched_rupees: number;
  ageing_days: number | null;
  matched_pct: number | null;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    unitPairRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3623_recon_status_rollup'),
    supabase.rpc('founder_r3623_unit_pair_scorecard'),
    supabase.rpc('founder_r3623_unit_pair_status_matrix'),
    supabase.rpc('founder_r3623_monthly_recon_trend'),
    supabase.rpc('founder_r3623_capa_status_board'),
    supabase.rpc('founder_r3623_root_cause_pareto'),
    supabase.rpc('founder_r3623_unmatched_impact_digest'),
    supabase.rpc('founder_r3623_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const unitPairRows: UnitPairRow[] = (unitPairRes.data as UnitPairRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'recon_status', header: 'Recon Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_unmatched_rupees', header: 'Unmatched (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const unitPairCols: Column<UnitPairRow>[] = [
    { key: 'unit_pair', header: 'Unit Pair' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_receivable_rupees', header: 'Receivable (INR)' },
    { key: 'total_payable_rupees', header: 'Payable (INR)' },
    { key: 'total_difference_rupees', header: 'Difference (INR)' },
    { key: 'total_unmatched_rupees', header: 'Unmatched (INR)' },
    { key: 'avg_matched_pct', header: 'Avg Matched %' },
    { key: 'unreconciled', header: 'Unreconciled / Disputed' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'unit_pair', header: 'Unit Pair' },
    { key: 'recon_status', header: 'Recon Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_unmatched_rupees', header: 'Unmatched (INR)' },
    { key: 'avg_ageing_days', header: 'Avg Ageing Days' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_difference_rupees', header: 'Difference (INR)' },
    { key: 'total_unmatched_rupees', header: 'Unmatched (INR)' },
    { key: 'avg_matched_pct', header: 'Avg Matched %' },
    { key: 'material_or_unreconciled', header: 'Material / Unreconciled' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'recon_status', header: 'Recon Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_unmatched_rupees', header: 'Unmatched (INR)' },
    { key: 'total_difference_rupees', header: 'Difference (INR)' },
    { key: 'avg_ageing_days', header: 'Avg Ageing Days' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'unit_pair', header: 'Unit Pair' },
    { key: 'recon_ref', header: 'Recon Ref' },
    { key: 'period_month', header: 'Month' },
    { key: 'recon_status', header: 'Status' },
    { key: 'difference_rupees', header: 'Difference (INR)' },
    { key: 'unmatched_rupees', header: 'Unmatched (INR)' },
    { key: 'ageing_days', header: 'Ageing Days' },
    { key: 'matched_pct', header: 'Matched %' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Inter-Unit / Inter-Company Balance Reconciliation Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated inter-unit &amp; inter-company balance reconciliation — unit-pair (HO &times;
        branches, amc_services, spare_parts, projects, diagnostics, inter-company entities) &times;
        period &times; receivable balance &times; payable balance &times; difference &times; matched
        &times; unmatched &times; ageing &times; matched-% &times; recon status &amp; CAPA closure with
        unmatched aging per unit-pair. Reconciliation view: recon-status distribution, unit-pair
        scorecards, unit-pair &times; status matrix, monthly trend, root-cause pareto, unmatched-impact
        digest, and a high-risk queue for material-diff, unreconciled &amp; disputed balances.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Recon-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No reconciliation entries logged yet."
          rowKey={(r, i) => String(r.recon_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Unit-pair scorecard</h2>
        <DataTable
          rows={unitPairRows}
          columns={unitPairCols}
          emptyMessage="No unit-pair rollups."
          rowKey={(r, i) => String(r.unit_pair ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Unit-pair &times; recon-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No entries by unit-pair."
          rowKey={(r, i) => `${r.unit_pair}-${r.recon_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly reconciliation trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Unmatched-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No unmatched-impact rollups."
          rowKey={(r, i) => String(r.recon_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk reconciliation queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk balances."
          rowKey={(r, i) => `${r.recon_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
