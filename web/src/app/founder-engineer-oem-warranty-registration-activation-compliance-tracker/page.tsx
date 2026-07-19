import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { registration_verdict: string; installs: number; pct: number };
type EngineerRow = {
  engineer_name: string;
  total_installs: number;
  activated: number;
  pending: number;
  overdue_at_risk: number;
  lapsed_void: number;
  activated_late: number;
  submitted: number;
  activation_pct: number;
};
type MatrixRow = {
  equipment_type: string;
  oem_vendor: string;
  installs: number;
  activated: number;
  lapsed: number;
  avg_days_to_deadline: number;
};
type TrendRow = {
  install_date: string;
  installs: number;
  activated: number;
  overdue_at_risk: number;
  lapsed_void: number;
  not_submitted: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_exposure_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_exposure_rupees: number;
  pct: number;
};
type ExposureRow = {
  exposure_tier: string;
  findings: number;
  open_findings: number;
  total_exposure_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  hospital_name: string;
  install_code: string;
  equipment_type: string;
  oem_vendor: string;
  install_date: string;
  registration_deadline: string;
  days_to_deadline: number;
  blocking_reason: string | null;
  registration_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    engineerRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    exposureRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3356_registration_verdict_rollup'),
    supabase.rpc('founder_r3356_engineer_scorecard'),
    supabase.rpc('founder_r3356_equipment_vendor_matrix'),
    supabase.rpc('founder_r3356_daily_registration_trend'),
    supabase.rpc('founder_r3356_capa_status_board'),
    supabase.rpc('founder_r3356_root_cause_pareto'),
    supabase.rpc('founder_r3356_exposure_risk_digest'),
    supabase.rpc('founder_r3356_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const engineerRows: EngineerRow[] = (engineerRes.data as EngineerRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const exposureRows: ExposureRow[] = (exposureRes.data as ExposureRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'registration_verdict', header: 'Verdict' },
    { key: 'installs', header: 'Installs' },
    { key: 'pct', header: 'Share %' },
  ];

  const engineerCols: Column<EngineerRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'total_installs', header: 'Installs' },
    { key: 'activated', header: 'Activated' },
    { key: 'pending', header: 'Pending' },
    { key: 'overdue_at_risk', header: 'Overdue / At-Risk' },
    { key: 'lapsed_void', header: 'Lapsed / Void' },
    { key: 'activated_late', header: 'Activated Late' },
    { key: 'submitted', header: 'Submitted' },
    { key: 'activation_pct', header: 'Activation %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'equipment_type', header: 'Equipment Type' },
    { key: 'oem_vendor', header: 'OEM Vendor' },
    { key: 'installs', header: 'Installs' },
    { key: 'activated', header: 'Activated' },
    { key: 'lapsed', header: 'Lapsed' },
    { key: 'avg_days_to_deadline', header: 'Avg Days To Deadline' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'install_date', header: 'Install Date' },
    { key: 'installs', header: 'Installs' },
    { key: 'activated', header: 'Activated' },
    { key: 'overdue_at_risk', header: 'Overdue / At-Risk' },
    { key: 'lapsed_void', header: 'Lapsed / Void' },
    { key: 'not_submitted', header: 'Not Submitted' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_exposure_rupees', header: 'Avg Exposure (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_exposure_rupees', header: 'Total Exposure (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const exposureCols: Column<ExposureRow>[] = [
    { key: 'exposure_tier', header: 'Exposure Tier' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_exposure_rupees', header: 'Total Exposure (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'install_code', header: 'Install' },
    { key: 'equipment_type', header: 'Equipment' },
    { key: 'oem_vendor', header: 'OEM Vendor' },
    { key: 'install_date', header: 'Install Date' },
    { key: 'registration_deadline', header: 'Deadline' },
    { key: 'days_to_deadline', header: 'Days To Deadline' },
    { key: 'blocking_reason', header: 'Blocking Reason' },
    { key: 'registration_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer OEM Warranty Registration &amp; Activation Compliance Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Install-time warranty compliance log — equipment type &times; OEM vendor &times; registration
        window &times; submission &amp; OEM activation &times; blocking reason &times; days-to-deadline
        &amp; CAPA closure. When equipment is installed, engineers must register the serial with the OEM
        within the window to activate coverage; a missed registration voids the warranty and creates
        financial exposure. Founder-gated view: registration verdicts, engineer scorecards, root-cause
        pareto, and exposure-risk digest across at-risk installs.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Registration verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No installs logged yet."
          rowKey={(r, i) => String(r.registration_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer compliance scorecard</h2>
        <DataTable
          rows={engineerRows}
          columns={engineerCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Equipment type &times; OEM vendor matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No installs by equipment / vendor."
          rowKey={(r, i) => `${r.equipment_type}-${r.oem_vendor}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily registration trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.install_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Exposure-risk digest</h2>
        <DataTable
          rows={exposureRows}
          columns={exposureCols}
          emptyMessage="No exposure-risk rollups."
          rowKey={(r, i) => String(r.exposure_tier ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk registration queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk installs."
          rowKey={(r, i) => `${r.install_code}-${r.install_date}-${i}`}
        />
      </section>
    </main>
  );
}
