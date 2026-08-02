import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { audit_status: string; suppliers: number; pct: number };
type CatRow = {
  supply_category: string;
  suppliers: number;
  approved: number;
  conditional_or_probation: number;
  suspended_or_disqualified: number;
  avg_audit_score: number;
  avg_on_time_delivery_pct: number;
  avg_lot_rejection_pct: number;
  open_findings: number;
  open_scars: number;
};
type MatrixRow = {
  qualification_tier: string;
  audit_status: string;
  suppliers: number;
  avg_audit_score: number;
  findings_open: number;
};
type TrendRow = {
  period_month: string;
  suppliers: number;
  requal_due: number;
  audit_overdue: number;
  avg_audit_score: number;
  avg_on_time_delivery_pct: number;
  avg_lot_rejection_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type ImpactRow = {
  rejection_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  supplier_code: string;
  supplier_name: string;
  supply_category: string;
  period_month: string;
  qualification_tier: string;
  audit_status: string;
  trend_dir: string;
  last_audit_score: number | null;
  audit_findings_open: number;
  scar_open: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    catRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3657_audit_status_rollup'),
    supabase.rpc('founder_r3657_supply_category_scorecard'),
    supabase.rpc('founder_r3657_tier_audit_status_matrix'),
    supabase.rpc('founder_r3657_monthly_audit_trend'),
    supabase.rpc('founder_r3657_capa_status_board'),
    supabase.rpc('founder_r3657_root_cause_pareto'),
    supabase.rpc('founder_r3657_rejection_impact_digest'),
    supabase.rpc('founder_r3657_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const catRows: CatRow[] = (catRes.data as CatRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'audit_status', header: 'Audit Status' },
    { key: 'suppliers', header: 'Suppliers' },
    { key: 'pct', header: 'Share %' },
  ];

  const catCols: Column<CatRow>[] = [
    { key: 'supply_category', header: 'Supply Category' },
    { key: 'suppliers', header: 'Suppliers' },
    { key: 'approved', header: 'Approved' },
    { key: 'conditional_or_probation', header: 'Conditional / Probation' },
    { key: 'suspended_or_disqualified', header: 'Suspended / DQ' },
    { key: 'avg_audit_score', header: 'Avg Audit Score' },
    { key: 'avg_on_time_delivery_pct', header: 'Avg OTD %' },
    { key: 'avg_lot_rejection_pct', header: 'Avg Lot Rej %' },
    { key: 'open_findings', header: 'Open Findings' },
    { key: 'open_scars', header: 'Open SCARs' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'qualification_tier', header: 'Qualification Tier' },
    { key: 'audit_status', header: 'Audit Status' },
    { key: 'suppliers', header: 'Suppliers' },
    { key: 'avg_audit_score', header: 'Avg Audit Score' },
    { key: 'findings_open', header: 'Findings Open' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'suppliers', header: 'Suppliers' },
    { key: 'requal_due', header: 'Requal Due' },
    { key: 'audit_overdue', header: 'Audit Overdue' },
    { key: 'avg_audit_score', header: 'Avg Audit Score' },
    { key: 'avg_on_time_delivery_pct', header: 'Avg OTD %' },
    { key: 'avg_lot_rejection_pct', header: 'Avg Lot Rej %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'rejection_impact', header: 'Rejection Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'supplier_code', header: 'Code' },
    { key: 'supplier_name', header: 'Supplier' },
    { key: 'supply_category', header: 'Category' },
    { key: 'period_month', header: 'Month' },
    { key: 'qualification_tier', header: 'Tier' },
    { key: 'audit_status', header: 'Audit Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'last_audit_score', header: 'Audit Score' },
    { key: 'audit_findings_open', header: 'Findings Open' },
    { key: 'scar_open', header: 'SCARs Open' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Approved-Supplier Qualification / Audit (AVL) Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Approved-vendor-list qualification and audit lifecycle — supply category &times;
        qualification tier &times; audit status &times; requalification window &times; last audit
        score &times; on-time delivery &times; lot rejection &times; open SCARs &amp; CAPA closure.
        Founder-gated view: audit-status rollups, supply-category scorecards, tier &times; status
        matrix, root-cause pareto, rejection-impact digest, and the suspended / audit-overdue
        high-risk supplier queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Audit status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No suppliers logged yet."
          rowKey={(r, i) => String(r.audit_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Supply-category scorecard</h2>
        <DataTable
          rows={catRows}
          columns={catCols}
          emptyMessage="No supply-category rollups."
          rowKey={(r, i) => String(r.supply_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Qualification tier &times; audit status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No suppliers by tier."
          rowKey={(r, i) => `${r.qualification_tier}-${r.audit_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly audit trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Rejection-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No rejection-impact rollups."
          rowKey={(r, i) => String(r.rejection_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk supplier queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk suppliers."
          rowKey={(r, i) => `${r.supplier_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
