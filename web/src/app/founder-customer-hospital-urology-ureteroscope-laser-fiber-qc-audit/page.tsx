import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { qc_verdict: string; checks: number; pct: number };
type ScoreRow = {
  hospital_name: string;
  total_checks: number;
  passed: number;
  conditional: number;
  failed: number;
  image_fail: number;
  leak_issue: number;
  calibration_overdue: number;
  pass_pct: number;
};
type MatrixRow = { device_type: string; department: string; checks: number; passed: number; failed: number; fiber_issue: number };
type TrendRow = { check_date: string; checks: number; passed: number; failed: number; image_fail: number; leak_issue: number };
type CapaRow = { capa_status: string; findings: number; avg_cost_rupees: number; overdue_flag: number };
type CauseRow = { root_cause: string; occurrences: number; total_cost_rupees: number; pct: number };
type RegRow = { regulatory_impact: string; findings: number; open_findings: number; total_cost_rupees: number };
type RiskRow = {
  hospital_name: string;
  scope_code: string;
  device_type: string;
  department: string;
  check_date: string;
  qc_verdict: string;
  image_quality: string;
  laser_fiber_transmission_ok: string;
  fiber_tip_condition: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [verdictRes, scoreRes, matrixRes, trendRes, capaRes, causeRes, regRes, riskRes] = await Promise.all([
    supabase.rpc('founder_r3390_qc_verdict_rollup'),
    supabase.rpc('founder_r3390_hospital_scorecard'),
    supabase.rpc('founder_r3390_device_department_matrix'),
    supabase.rpc('founder_r3390_daily_qc_trend'),
    supabase.rpc('founder_r3390_capa_status_board'),
    supabase.rpc('founder_r3390_root_cause_pareto'),
    supabase.rpc('founder_r3390_regulatory_impact_digest'),
    supabase.rpc('founder_r3390_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const scoreRows: ScoreRow[] = (scoreRes.data as ScoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'checks', header: 'Checks' },
    { key: 'pct', header: 'Share %' },
  ];
  const scoreCols: Column<ScoreRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'failed', header: 'Failed' },
    { key: 'image_fail', header: 'Image Issue' },
    { key: 'leak_issue', header: 'Leak Issue' },
    { key: 'calibration_overdue', header: 'Cal Overdue' },
    { key: 'pass_pct', header: 'Pass %' },
  ];
  const matrixCols: Column<MatrixRow>[] = [
    { key: 'device_type', header: 'Device Type' },
    { key: 'department', header: 'Department' },
    { key: 'checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'fiber_issue', header: 'Fiber Issue' },
  ];
  const trendCols: Column<TrendRow>[] = [
    { key: 'check_date', header: 'Date' },
    { key: 'checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'image_fail', header: 'Image Issue' },
    { key: 'leak_issue', header: 'Leak Issue' },
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
  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Regulatory Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];
  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'scope_code', header: 'Scope/Fiber' },
    { key: 'device_type', header: 'Device Type' },
    { key: 'department', header: 'Department' },
    { key: 'check_date', header: 'Date' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'image_quality', header: 'Image' },
    { key: 'laser_fiber_transmission_ok', header: 'Fiber Txn' },
    { key: 'fiber_tip_condition', header: 'Fiber Tip' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Urology Ureteroscope &amp; Laser-Fiber QC Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Flexible/semi-rigid/digital ureteroscopes &amp; holmium laser fibers &mdash; deflection &times; optics
        &times; channel patency &times; leak &times; fiber transmission &times; tip condition &times; sterilization
        &amp; reprocessing traceability &amp; CAPA. Founder-gated view: verdict rollup, hospital scorecard,
        device &times; department matrix, and high-risk scope/fiber queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. QC verdict distribution</h2>
        <DataTable rows={verdictRows} columns={verdictCols} emptyMessage="No scopes checked yet." rowKey={(r, i) => String(r.qc_verdict ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital QC scorecard</h2>
        <DataTable rows={scoreRows} columns={scoreCols} emptyMessage="No hospital rollups." rowKey={(r, i) => String(r.hospital_name ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Device-type &times; department matrix</h2>
        <DataTable rows={matrixRows} columns={matrixCols} emptyMessage="No matrix data." rowKey={(r, i) => `${r.device_type}-${r.department}-${i}`} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily QC trend</h2>
        <DataTable rows={trendRows} columns={trendCols} emptyMessage="No trend data." rowKey={(r, i) => String(r.check_date ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable rows={capaRows} columns={capaCols} emptyMessage="No CAPA findings." rowKey={(r, i) => String(r.capa_status ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable rows={causeRows} columns={causeCols} emptyMessage="No root-cause data." rowKey={(r, i) => String(r.root_cause ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable rows={regRows} columns={regCols} emptyMessage="No regulatory-impact rollups." rowKey={(r, i) => String(r.regulatory_impact ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk scope/fiber queue</h2>
        <DataTable rows={riskRows} columns={riskCols} emptyMessage="No high-risk scopes." rowKey={(r, i) => `${r.scope_code}-${i}`} />
      </section>
    </main>
  );
}
