import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { request_verdict: string; requests: number; pct: number };
type DeptRow = {
  requesting_department: string;
  total_requests: number;
  approved: number;
  deferred: number;
  rejected: number;
  total_capex_rupees: number;
  board_needed: number;
  avg_priority_score: number;
};
type MatrixRow = {
  asset_category: string;
  strategic_alignment: string;
  requests: number;
  approved: number;
  total_capex_rupees: number;
  avg_payback_months: number;
};
type TrendRow = {
  request_date: string;
  requests: number;
  approved: number;
  deferred: number;
  rejected: number;
  total_capex_rupees: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_capex_at_stake_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_capex_at_stake_rupees: number;
  pct: number;
};
type ImpactRow = {
  funding_impact: string;
  actions: number;
  open_actions: number;
  total_capex_at_stake_rupees: number;
};
type RiskRow = {
  request_ref: string;
  requesting_department: string;
  asset_category: string;
  request_title: string;
  request_date: string;
  capex_amount_rupees: number;
  strategic_alignment: string;
  risk_level: string;
  approval_stage: string;
  request_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    deptRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3425_verdict_rollup'),
    supabase.rpc('founder_r3425_department_scorecard'),
    supabase.rpc('founder_r3425_category_alignment_matrix'),
    supabase.rpc('founder_r3425_daily_request_trend'),
    supabase.rpc('founder_r3425_capa_status_board'),
    supabase.rpc('founder_r3425_root_cause_pareto'),
    supabase.rpc('founder_r3425_funding_impact_digest'),
    supabase.rpc('founder_r3425_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const deptRows: DeptRow[] = (deptRes.data as DeptRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'request_verdict', header: 'Verdict' },
    { key: 'requests', header: 'Requests' },
    { key: 'pct', header: 'Share %' },
  ];

  const deptCols: Column<DeptRow>[] = [
    { key: 'requesting_department', header: 'Department' },
    { key: 'total_requests', header: 'Requests' },
    { key: 'approved', header: 'Approved' },
    { key: 'deferred', header: 'Deferred' },
    { key: 'rejected', header: 'Rejected' },
    { key: 'total_capex_rupees', header: 'Total Capex (INR)' },
    { key: 'board_needed', header: 'Board-Gated' },
    { key: 'avg_priority_score', header: 'Avg Priority' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'asset_category', header: 'Asset Category' },
    { key: 'strategic_alignment', header: 'Alignment' },
    { key: 'requests', header: 'Requests' },
    { key: 'approved', header: 'Approved' },
    { key: 'total_capex_rupees', header: 'Total Capex (INR)' },
    { key: 'avg_payback_months', header: 'Avg Payback (mo)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'request_date', header: 'Date' },
    { key: 'requests', header: 'Requests' },
    { key: 'approved', header: 'Approved' },
    { key: 'deferred', header: 'Deferred' },
    { key: 'rejected', header: 'Rejected' },
    { key: 'total_capex_rupees', header: 'Total Capex (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_capex_at_stake_rupees', header: 'Avg Capex at Stake (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_capex_at_stake_rupees', header: 'Total Capex at Stake (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'funding_impact', header: 'Funding Impact' },
    { key: 'actions', header: 'Actions' },
    { key: 'open_actions', header: 'Open' },
    { key: 'total_capex_at_stake_rupees', header: 'Total Capex at Stake (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'request_ref', header: 'Request' },
    { key: 'requesting_department', header: 'Department' },
    { key: 'asset_category', header: 'Category' },
    { key: 'request_title', header: 'Title' },
    { key: 'request_date', header: 'Date' },
    { key: 'capex_amount_rupees', header: 'Capex (INR)' },
    { key: 'strategic_alignment', header: 'Alignment' },
    { key: 'risk_level', header: 'Risk' },
    { key: 'approval_stage', header: 'Stage' },
    { key: 'request_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Capex-Approval Pipeline &amp; Capital-Request Prioritization Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Pre-approval funding-gate governance for EquipSeva capital requests &mdash; request verdict
        &times; requesting department &times; asset-category &amp; strategic-alignment matrix &times;
        projected payback &times; priority score &times; budget gate &times; board gate &amp; CAPA
        (review / rework / funding) closure. Founder-gated view: verdict rollups, department
        scorecards, root-cause pareto, and funding-impact digest &mdash; complementing the post-audit
        board with a pre-approval prioritization lens across field-engineering, calibration-lab,
        IT-infra, sales-ops, logistics &amp; workshop demand.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Request verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No capital requests logged yet."
          rowKey={(r, i) => String(r.request_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Department pipeline scorecard</h2>
        <DataTable
          rows={deptRows}
          columns={deptCols}
          emptyMessage="No department rollups."
          rowKey={(r, i) => String(r.requesting_department ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>
          3. Asset category &times; strategic alignment matrix
        </h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No requests by asset category."
          rowKey={(r, i) => `${r.asset_category}-${r.strategic_alignment}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily request-submission trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.request_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Funding impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No funding-impact rollups."
          rowKey={(r, i) => String(r.funding_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk request queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk requests."
          rowKey={(r, i) => `${r.request_ref}-${r.request_date}-${i}`}
        />
      </section>
    </main>
  );
}
