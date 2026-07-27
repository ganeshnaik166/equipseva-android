import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { approval_status: string; deferrals: number; pct: number };
type PmTypeRow = {
  pm_type: string;
  total_deferrals: number;
  approved: number;
  pending: number;
  escalated: number;
  expired: number;
  rejected: number;
  high_risk: number;
  avg_deferral_days: number;
};
type MatrixRow = {
  deferral_reason: string;
  risk_level: string;
  deferrals: number;
  avg_deferral_days: number;
  pending_or_escalated: number;
};
type TrendRow = {
  deferral_month: string;
  deferrals: number;
  avg_deferral_days: number;
  high_risk: number;
  expired: number;
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
type DigestRow = {
  finding_category: string;
  findings: number;
  open_findings: number;
  total_risk_exposure: number;
  total_cost_rupees: number;
};
type RiskRow = {
  hospital_name: string;
  engineer_name: string;
  device_model: string;
  asset_tag: string;
  pm_type: string;
  deferral_reason: string;
  original_due: string;
  deferred_to: string;
  deferral_days: number;
  risk_level: string;
  approval_status: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    pmTypeRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3508_approval_status_rollup'),
    supabase.rpc('founder_r3508_pm_type_scorecard'),
    supabase.rpc('founder_r3508_reason_risk_matrix'),
    supabase.rpc('founder_r3508_monthly_deferral_trend'),
    supabase.rpc('founder_r3508_capa_status_board'),
    supabase.rpc('founder_r3508_root_cause_pareto'),
    supabase.rpc('founder_r3508_risk_exposure_digest'),
    supabase.rpc('founder_r3508_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const pmTypeRows: PmTypeRow[] = (pmTypeRes.data as PmTypeRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'approval_status', header: 'Approval Status' },
    { key: 'deferrals', header: 'Deferrals' },
    { key: 'pct', header: 'Share %' },
  ];

  const pmTypeCols: Column<PmTypeRow>[] = [
    { key: 'pm_type', header: 'PM Type' },
    { key: 'total_deferrals', header: 'Deferrals' },
    { key: 'approved', header: 'Approved' },
    { key: 'pending', header: 'Pending' },
    { key: 'escalated', header: 'Escalated' },
    { key: 'expired', header: 'Expired' },
    { key: 'rejected', header: 'Rejected' },
    { key: 'high_risk', header: 'High/Critical' },
    { key: 'avg_deferral_days', header: 'Avg Days' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'deferral_reason', header: 'Deferral Reason' },
    { key: 'risk_level', header: 'Risk Level' },
    { key: 'deferrals', header: 'Deferrals' },
    { key: 'avg_deferral_days', header: 'Avg Days' },
    { key: 'pending_or_escalated', header: 'Pending / Escalated' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'deferral_month', header: 'Month' },
    { key: 'deferrals', header: 'Deferrals' },
    { key: 'avg_deferral_days', header: 'Avg Days' },
    { key: 'high_risk', header: 'High/Critical' },
    { key: 'expired', header: 'Expired' },
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

  const digestCols: Column<DigestRow>[] = [
    { key: 'finding_category', header: 'Finding Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_risk_exposure', header: 'Risk Exposure' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'device_model', header: 'Device' },
    { key: 'asset_tag', header: 'Asset Tag' },
    { key: 'pm_type', header: 'PM Type' },
    { key: 'deferral_reason', header: 'Reason' },
    { key: 'original_due', header: 'Original Due' },
    { key: 'deferred_to', header: 'Deferred To' },
    { key: 'deferral_days', header: 'Days' },
    { key: 'risk_level', header: 'Risk' },
    { key: 'approval_status', header: 'Status' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Preventive-Maintenance Deferral / Risk-Acceptance Approval Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Preventive-maintenance deferral &amp; risk-acceptance approval log — engineer &times; hospital
        &times; device &times; PM type (scheduled PM, calibration, safety test, statutory inspection,
        OEM service) &times; deferral reason &times; deferral window (original due &rarr; deferred-to,
        days) &times; risk level &times; approval status &amp; CAPA closure. Founder-gated view:
        approval-status rollup, PM-type scorecard, reason &times; risk matrix, monthly deferral trend,
        root-cause pareto, and risk-exposure impact digest across statutory &amp; safety surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Approval-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No deferrals logged yet."
          rowKey={(r, i) => String(r.approval_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. PM-type scorecard</h2>
        <DataTable
          rows={pmTypeRows}
          columns={pmTypeCols}
          emptyMessage="No PM-type rollups."
          rowKey={(r, i) => String(r.pm_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Deferral reason &times; risk-level matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No deferrals by reason."
          rowKey={(r, i) => `${r.deferral_reason}-${r.risk_level}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly deferral trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.deferral_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Risk-exposure impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No risk-exposure rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk deferral queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk deferrals."
          rowKey={(r, i) => `${r.asset_tag}-${r.original_due}-${i}`}
        />
      </section>
    </main>
  );
}
