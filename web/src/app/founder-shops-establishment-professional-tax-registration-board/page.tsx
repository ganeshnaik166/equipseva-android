import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { compliance_status: string; registrations: number; pct: number };
type StateRow = {
  state_region: string;
  registrations: number;
  compliant: number;
  renewal_due: number;
  remittance_gap: number;
  notices_open_total: number;
  employees_covered_total: number;
  avg_pt_on_time_pct: number;
  compliant_pct: number;
};
type MatrixRow = {
  registration_type: string;
  compliance_status: string;
  registrations: number;
  notices_open_total: number;
  avg_days_to_expiry: number;
};
type TrendRow = {
  period_month: string;
  registrations: number;
  compliant: number;
  gaps: number;
  notices: number;
  avg_pt_on_time_pct: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_penalty_exposure_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_penalty_exposure_rupees: number;
  pct: number;
};
type RemitRow = {
  office_location: string;
  state_region: string;
  registrations: number;
  remittance_gap_regs: number;
  lwf_missed: number;
  avg_pt_on_time_pct: number;
  employees_at_risk: number;
};
type RiskRow = {
  office_location: string;
  state_region: string;
  se_registration_no: string;
  registration_type: string;
  period_month: string;
  compliance_status: string;
  days_to_expiry: number | null;
  notices_open: number;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    stateRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    remitRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3681_compliance_status_rollup'),
    supabase.rpc('founder_r3681_state_scorecard'),
    supabase.rpc('founder_r3681_regtype_status_matrix'),
    supabase.rpc('founder_r3681_monthly_compliance_trend'),
    supabase.rpc('founder_r3681_capa_status_board'),
    supabase.rpc('founder_r3681_root_cause_pareto'),
    supabase.rpc('founder_r3681_remittance_gap_digest'),
    supabase.rpc('founder_r3681_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const stateRows: StateRow[] = (stateRes.data as StateRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const remitRows: RemitRow[] = (remitRes.data as RemitRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'registrations', header: 'Registrations' },
    { key: 'pct', header: 'Share %' },
  ];

  const stateCols: Column<StateRow>[] = [
    { key: 'state_region', header: 'State' },
    { key: 'registrations', header: 'Registrations' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'renewal_due', header: 'Renewal Due' },
    { key: 'remittance_gap', header: 'Remittance Gap' },
    { key: 'notices_open_total', header: 'Notices Open' },
    { key: 'employees_covered_total', header: 'Employees Covered' },
    { key: 'avg_pt_on_time_pct', header: 'Avg PT On-Time %' },
    { key: 'compliant_pct', header: 'Compliant %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'registration_type', header: 'Registration Type' },
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'registrations', header: 'Registrations' },
    { key: 'notices_open_total', header: 'Notices Open' },
    { key: 'avg_days_to_expiry', header: 'Avg Days to Expiry' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'registrations', header: 'Registrations' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'gaps', header: 'Remittance / Display Gaps' },
    { key: 'notices', header: 'Notices Received' },
    { key: 'avg_pt_on_time_pct', header: 'Avg PT On-Time %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_penalty_exposure_rupees', header: 'Avg Penalty Exposure (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_penalty_exposure_rupees', header: 'Total Penalty Exposure (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const remitCols: Column<RemitRow>[] = [
    { key: 'office_location', header: 'Office' },
    { key: 'state_region', header: 'State' },
    { key: 'registrations', header: 'Registrations Flagged' },
    { key: 'remittance_gap_regs', header: 'Remittance Gaps' },
    { key: 'lwf_missed', header: 'LWF Missed' },
    { key: 'avg_pt_on_time_pct', header: 'Avg PT On-Time %' },
    { key: 'employees_at_risk', header: 'Employees at Risk' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'office_location', header: 'Office' },
    { key: 'state_region', header: 'State' },
    { key: 'se_registration_no', header: 'Registration No' },
    { key: 'registration_type', header: 'Type' },
    { key: 'period_month', header: 'Month' },
    { key: 'compliance_status', header: 'Status' },
    { key: 'days_to_expiry', header: 'Days to Expiry' },
    { key: 'notices_open', header: 'Notices Open' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Shops &amp; Establishment / Professional-Tax Registration Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Statutory premises compliance board — shops &amp; establishment registration &times;
        professional-tax enrolment &amp; remittance &times; labour welfare fund &times; trade &amp;
        signage licences across Mumbai HQ, Chennai Service Hub, Delhi Warehouse and Bengaluru
        Refurb Center. Founder-gated view: compliance-status rollups, state scorecards,
        registration-type &times; status matrix, remittance-gap digest, root-cause pareto and the
        notice / remittance high-risk queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No registrations logged yet."
          rowKey={(r, i) => String(r.compliance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. State compliance scorecard</h2>
        <DataTable
          rows={stateRows}
          columns={stateCols}
          emptyMessage="No state rollups."
          rowKey={(r, i) => String(r.state_region ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Registration type &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No registrations by type."
          rowKey={(r, i) => `${r.registration_type}-${r.compliance_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly compliance trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Remittance-gap digest</h2>
        <DataTable
          rows={remitRows}
          columns={remitCols}
          emptyMessage="No remittance gaps flagged."
          rowKey={(r, i) => `${r.office_location}-${r.state_region}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk registration queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk registrations."
          rowKey={(r, i) => `${r.se_registration_no}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
