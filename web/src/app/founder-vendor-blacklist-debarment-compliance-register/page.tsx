import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { debarment_status: string; vendors: number; pct: number };
type CategoryRow = {
  supply_category: string;
  vendors: number;
  active_debarments: number;
  under_review: number;
  appeal_pending: number;
  reinstated: number;
  permanent_bans: number;
  alternate_identified: number;
  total_prior_spend_rupees: number;
};
type MatrixRow = {
  debarment_reason_class: string;
  debarment_status: string;
  vendors: number;
  total_prior_spend_rupees: number;
};
type TrendRow = {
  period_month: string;
  vendors: number;
  new_debarments: number;
  reinstated: number;
  permanent_bans: number;
  total_prior_spend_rupees: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  pct: number;
};
type ExposureRow = {
  debarment_reason_class: string;
  vendors: number;
  total_prior_spend_rupees: number;
  no_alternate_vendor: number;
  appeals_filed: number;
  reinstatement_eligible: number;
};
type RiskRow = {
  vendor_name: string;
  supply_category: string;
  debarment_ref: string;
  debarment_status: string;
  debarment_reason_class: string;
  review_due_date: string | null;
  prior_annual_spend_rupees: number | null;
  alternate_vendor_identified: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    categoryRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    exposureRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3723_debarment_status_rollup'),
    supabase.rpc('founder_r3723_supply_category_scorecard'),
    supabase.rpc('founder_r3723_debarment_reason_class_status_matrix'),
    supabase.rpc('founder_r3723_monthly_debarment_trend'),
    supabase.rpc('founder_r3723_capa_status_board'),
    supabase.rpc('founder_r3723_root_cause_pareto'),
    supabase.rpc('founder_r3723_exposure_digest'),
    supabase.rpc('founder_r3723_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const exposureRows: ExposureRow[] = (exposureRes.data as ExposureRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'debarment_status', header: 'Debarment Status' },
    { key: 'vendors', header: 'Vendors' },
    { key: 'pct', header: 'Share %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'supply_category', header: 'Supply Category' },
    { key: 'vendors', header: 'Vendors' },
    { key: 'active_debarments', header: 'Active' },
    { key: 'under_review', header: 'Under Review' },
    { key: 'appeal_pending', header: 'Appeal Pending' },
    { key: 'reinstated', header: 'Reinstated' },
    { key: 'permanent_bans', header: 'Permanent Bans' },
    { key: 'alternate_identified', header: 'Alt. Vendor Identified' },
    { key: 'total_prior_spend_rupees', header: 'Prior Spend (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'debarment_reason_class', header: 'Reason Class' },
    { key: 'debarment_status', header: 'Debarment Status' },
    { key: 'vendors', header: 'Vendors' },
    { key: 'total_prior_spend_rupees', header: 'Prior Spend (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'vendors', header: 'Vendors' },
    { key: 'new_debarments', header: 'Active Debarments' },
    { key: 'reinstated', header: 'Reinstated' },
    { key: 'permanent_bans', header: 'Permanent Bans' },
    { key: 'total_prior_spend_rupees', header: 'Prior Spend (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'overdue_flag', header: 'Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const exposureCols: Column<ExposureRow>[] = [
    { key: 'debarment_reason_class', header: 'Reason Class' },
    { key: 'vendors', header: 'Vendors' },
    { key: 'total_prior_spend_rupees', header: 'Prior Spend (INR)' },
    { key: 'no_alternate_vendor', header: 'No Alternate Vendor' },
    { key: 'appeals_filed', header: 'Appeals Filed' },
    { key: 'reinstatement_eligible', header: 'Reinstatement Eligible' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'vendor_name', header: 'Vendor' },
    { key: 'supply_category', header: 'Supply Category' },
    { key: 'debarment_ref', header: 'Debarment Ref' },
    { key: 'debarment_status', header: 'Debarment Status' },
    { key: 'debarment_reason_class', header: 'Reason Class' },
    { key: 'review_due_date', header: 'Review Due' },
    { key: 'prior_annual_spend_rupees', header: 'Prior Spend (INR)' },
    { key: 'alternate_vendor_identified', header: 'Alt. Vendor Identified' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Vendor Blacklist / Debarment Compliance Register
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Vendor &amp; supplier blacklist / debarment register — grounds for debarment, review
        &amp; appeal status, re-engagement eligibility, and prior spend exposure. Distinct from
        the vendor-contract risk register and vendor-contract vault, which track live contract
        risk rather than debarment actions. Founder-gated view: debarment-status distribution,
        supply-category scorecards, reason-class &times; status matrix, monthly trend, CAPA
        closure, root-cause pareto, spend-exposure digest, and a high-risk queue of active
        debarments &amp; permanent bans with no alternate vendor identified.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Debarment-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No debarment rows logged yet."
          rowKey={(r, i) => String(r.debarment_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Supply-category scorecard</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No supply-category rollups."
          rowKey={(r, i) => String(r.supply_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Reason class &times; debarment status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No reason-class data."
          rowKey={(r, i) => `${r.debarment_reason_class}-${r.debarment_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly debarment trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Spend-exposure digest by reason class</h2>
        <DataTable
          rows={exposureRows}
          columns={exposureCols}
          emptyMessage="No exposure rollups."
          rowKey={(r, i) => String(r.debarment_reason_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk debarment queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk debarments."
          rowKey={(r, i) => `${r.vendor_name}-${r.debarment_ref}-${i}`}
        />
      </section>
    </main>
  );
}
