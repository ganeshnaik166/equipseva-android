import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { job_verdict: string; jobs: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_jobs: number;
  verified: number;
  with_issues: number;
  delayed_escalated: number;
  calibration_fail: number;
  electrical_fail: number;
  damage_jobs: number;
  verified_pct: number;
};
type MatrixRow = {
  equipment_type: string;
  relocation_type: string;
  jobs: number;
  verified: number;
  avg_downtime_days: number;
  damage_jobs: number;
};
type TrendRow = {
  de_install_date: string;
  jobs: number;
  verified: number;
  with_issues: number;
  delayed_escalated: number;
  avg_downtime_days: number;
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
type RegRow = {
  regulatory_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  hospital_name: string;
  engineer_name: string;
  job_code: string;
  equipment_type: string;
  de_install_date: string;
  job_verdict: string;
  damage_during_move: string;
  calibration_post_move_ok: boolean | null;
  safety_electrical_test_ok: boolean | null;
  downtime_days: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3308_job_verdict_rollup'),
    supabase.rpc('founder_r3308_hospital_scorecard'),
    supabase.rpc('founder_r3308_equipment_relocation_matrix'),
    supabase.rpc('founder_r3308_daily_job_trend'),
    supabase.rpc('founder_r3308_capa_status_board'),
    supabase.rpc('founder_r3308_root_cause_pareto'),
    supabase.rpc('founder_r3308_regulatory_impact_digest'),
    supabase.rpc('founder_r3308_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'job_verdict', header: 'Verdict' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_jobs', header: 'Jobs' },
    { key: 'verified', header: 'Verified' },
    { key: 'with_issues', header: 'With Issues' },
    { key: 'delayed_escalated', header: 'Delayed / Escalated' },
    { key: 'calibration_fail', header: 'Cal Fail' },
    { key: 'electrical_fail', header: 'Electrical Fail' },
    { key: 'damage_jobs', header: 'Damage Jobs' },
    { key: 'verified_pct', header: 'Verified %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'equipment_type', header: 'Equipment' },
    { key: 'relocation_type', header: 'Relocation Type' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'verified', header: 'Verified' },
    { key: 'avg_downtime_days', header: 'Avg Downtime (d)' },
    { key: 'damage_jobs', header: 'Damage Jobs' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'de_install_date', header: 'De-Install Date' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'verified', header: 'Verified' },
    { key: 'with_issues', header: 'With Issues' },
    { key: 'delayed_escalated', header: 'Delayed / Escalated' },
    { key: 'avg_downtime_days', header: 'Avg Downtime (d)' },
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
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'job_code', header: 'Job' },
    { key: 'equipment_type', header: 'Equipment' },
    { key: 'de_install_date', header: 'De-Install' },
    { key: 'job_verdict', header: 'Verdict' },
    { key: 'damage_during_move', header: 'Damage' },
    { key: 'calibration_post_move_ok', header: 'Cal OK' },
    { key: 'safety_electrical_test_ok', header: 'Electrical OK' },
    { key: 'downtime_days', header: 'Downtime (d)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Equipment Relocation, Re-Install &amp; Re-Commission Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Relocation discipline log — equipment type &times; relocation type &times; downtime days
        &times; pre-move backup &times; post-move calibration &times; electrical-safety test &times;
        transport damage &times; acceptance sign-off &amp; CAPA closure. Founder-gated view: job
        verdicts, hospital scorecards, root-cause pareto, and regulatory-impact digest across NABH,
        CDSCO &amp; AERB surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Job verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No relocation jobs logged yet."
          rowKey={(r, i) => String(r.job_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital relocation scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Equipment &times; relocation-type matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No jobs by type."
          rowKey={(r, i) => `${r.equipment_type}-${r.relocation_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily relocation-job trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.de_install_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk relocation queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk jobs."
          rowKey={(r, i) => `${r.job_code}-${r.de_install_date}-${i}`}
        />
      </section>
    </main>
  );
}
