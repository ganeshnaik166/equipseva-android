import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { recon_status: string; recons: number; pct: number };
type BankRow = {
  bank_name: string;
  total_recons: number;
  reconciled: number;
  minor_diff: number;
  material_diff: number;
  unreconciled: number;
  stale: number;
  total_difference_rupees: number;
  avg_reconciled_pct: number;
};
type MatrixRow = {
  bank_name: string;
  recon_status: string;
  recons: number;
  total_difference_rupees: number;
  avg_oldest_item_days: number;
};
type TrendRow = {
  period_month: string;
  recons: number;
  reconciled: number;
  material_diff: number;
  unreconciled: number;
  total_unreconciled_items: number;
  total_difference_rupees: number;
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
type ImpactRow = {
  finding_category: string;
  findings: number;
  open_findings: number;
  total_impact_rupees: number;
};
type RiskRow = {
  bank_name: string;
  bank_account: string;
  recon_ref: string;
  period_month: string;
  recon_status: string;
  difference_rupees: number | null;
  unreconciled_items_count: number | null;
  oldest_item_days: number | null;
  reconciled_pct: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    bankRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3627_recon_status_rollup'),
    supabase.rpc('founder_r3627_bank_scorecard'),
    supabase.rpc('founder_r3627_bank_status_matrix'),
    supabase.rpc('founder_r3627_monthly_recon_trend'),
    supabase.rpc('founder_r3627_capa_status_board'),
    supabase.rpc('founder_r3627_root_cause_pareto'),
    supabase.rpc('founder_r3627_unreconciled_impact_digest'),
    supabase.rpc('founder_r3627_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const bankRows: BankRow[] = (bankRes.data as BankRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'recon_status', header: 'Recon Status' },
    { key: 'recons', header: 'Recons' },
    { key: 'pct', header: 'Share %' },
  ];

  const bankCols: Column<BankRow>[] = [
    { key: 'bank_name', header: 'Bank' },
    { key: 'total_recons', header: 'Recons' },
    { key: 'reconciled', header: 'Reconciled' },
    { key: 'minor_diff', header: 'Minor Diff' },
    { key: 'material_diff', header: 'Material Diff' },
    { key: 'unreconciled', header: 'Unreconciled' },
    { key: 'stale', header: 'Stale Items' },
    { key: 'total_difference_rupees', header: 'Total Diff (INR)' },
    { key: 'avg_reconciled_pct', header: 'Avg Recon %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'bank_name', header: 'Bank' },
    { key: 'recon_status', header: 'Recon Status' },
    { key: 'recons', header: 'Recons' },
    { key: 'total_difference_rupees', header: 'Total Diff (INR)' },
    { key: 'avg_oldest_item_days', header: 'Avg Oldest Item Days' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'recons', header: 'Recons' },
    { key: 'reconciled', header: 'Reconciled' },
    { key: 'material_diff', header: 'Material Diff' },
    { key: 'unreconciled', header: 'Unreconciled' },
    { key: 'total_unreconciled_items', header: 'Unreconciled Items' },
    { key: 'total_difference_rupees', header: 'Total Diff (INR)' },
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

  const impactCols: Column<ImpactRow>[] = [
    { key: 'finding_category', header: 'Finding Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'bank_name', header: 'Bank' },
    { key: 'bank_account', header: 'Account' },
    { key: 'recon_ref', header: 'Recon Ref' },
    { key: 'period_month', header: 'Month' },
    { key: 'recon_status', header: 'Status' },
    { key: 'difference_rupees', header: 'Diff (INR)' },
    { key: 'unreconciled_items_count', header: 'Items' },
    { key: 'oldest_item_days', header: 'Oldest Days' },
    { key: 'reconciled_pct', header: 'Recon %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Bank Reconciliation (BRS) / Unreconciled-Items Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated bank reconciliation view — per bank account &times; month: book balance vs bank
        balance, net difference, uncleared cheques, deposits in transit, unreconciled-item count &amp;
        aging (oldest-item days), reconciled % and reconciliation status across amc_services,
        spare_parts, projects, diagnostics &amp; payroll accounts. Rollups cover status distribution,
        bank scorecards, bank &times; status matrix, monthly reconciliation trend, CAPA closure,
        root-cause pareto, unreconciled-impact digest &amp; a high-risk queue for material differences
        &amp; stale items.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Reconciliation status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No reconciliations logged yet."
          rowKey={(r, i) => String(r.recon_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Bank reconciliation scorecard</h2>
        <DataTable
          rows={bankRows}
          columns={bankCols}
          emptyMessage="No bank rollups."
          rowKey={(r, i) => String(r.bank_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Bank &times; reconciliation-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No reconciliations by bank."
          rowKey={(r, i) => `${r.bank_name}-${r.recon_status}-${i}`}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Unreconciled-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No impact rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk reconciliations."
          rowKey={(r, i) => `${r.recon_ref}-${i}`}
        />
      </section>
    </main>
  );
}
