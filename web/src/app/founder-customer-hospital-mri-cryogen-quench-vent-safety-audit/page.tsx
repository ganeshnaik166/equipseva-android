import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { audit_verdict: string; audits: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  passed: number;
  refill_required: number;
  quench_risk: number;
  scan_halt: number;
  cold_head_issues: number;
  low_helium: number;
  compliance_pct: number;
};
type MatrixRow = {
  field_strength_tesla: string;
  cold_head_status: string;
  audits: number;
  passed: number;
  avg_helium_pct: number;
  avg_boil_off: number;
};
type TrendRow = {
  check_date: string;
  audits: number;
  avg_helium_pct: number;
  avg_boil_off: number;
  refill_required: number;
  quench_risk: number;
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
  mri_suite_code: string;
  scanner_asset_tag: string;
  check_date: string;
  audit_verdict: string;
  helium_level_pct: number;
  cold_head_status: string;
  quench_pipe_integrity: string;
  o2_depletion_sensor_status: string;
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
    supabase.rpc('founder_r3154_verdict_rollup'),
    supabase.rpc('founder_r3154_hospital_scorecard'),
    supabase.rpc('founder_r3154_field_status_matrix'),
    supabase.rpc('founder_r3154_helium_daily_trend'),
    supabase.rpc('founder_r3154_capa_status_board'),
    supabase.rpc('founder_r3154_root_cause_pareto'),
    supabase.rpc('founder_r3154_regulatory_impact_digest'),
    supabase.rpc('founder_r3154_high_risk_audits'),
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
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'audits', header: 'Audits' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'passed', header: 'Pass' },
    { key: 'refill_required', header: 'Refill Req' },
    { key: 'quench_risk', header: 'Quench Risk' },
    { key: 'scan_halt', header: 'Scan Halt' },
    { key: 'cold_head_issues', header: 'Cold-Head Issues' },
    { key: 'low_helium', header: 'Low Helium' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'field_strength_tesla', header: 'Field Strength' },
    { key: 'cold_head_status', header: 'Cold-Head Status' },
    { key: 'audits', header: 'Audits' },
    { key: 'passed', header: 'Pass' },
    { key: 'avg_helium_pct', header: 'Avg Helium %' },
    { key: 'avg_boil_off', header: 'Avg Boil-Off %/mo' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'check_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'avg_helium_pct', header: 'Avg Helium %' },
    { key: 'avg_boil_off', header: 'Avg Boil-Off %/mo' },
    { key: 'refill_required', header: 'Refill Req' },
    { key: 'quench_risk', header: 'Quench Risk' },
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
    { key: 'mri_suite_code', header: 'Suite' },
    { key: 'scanner_asset_tag', header: 'Asset' },
    { key: 'check_date', header: 'Date' },
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'helium_level_pct', header: 'Helium %' },
    { key: 'cold_head_status', header: 'Cold-Head' },
    { key: 'quench_pipe_integrity', header: 'Quench Pipe' },
    { key: 'o2_depletion_sensor_status', header: 'O2 Sensor' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital MRI Cryogen-Level &amp; Quench-Vent Safety Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Per-scanner monthly MRI helium safety log — field strength &times; helium level &times; boil-off rate
        &times; cold-head status &times; quench-pipe integrity &times; O2 depletion sensor &times; magnetic-safety
        signage &amp; CAPA closure. Founder-gated view: verdict rollups, hospital scorecards, root-cause pareto,
        and regulatory-impact digest across NABH &amp; patient-safety surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Audit verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No audits logged yet."
          rowKey={(r, i) => String(r.audit_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital safety scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Field strength &times; cold-head matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No audits by field strength."
          rowKey={(r, i) => `${r.field_strength_tesla}-${r.cold_head_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Helium &amp; boil-off daily trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.check_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk priority queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk audits."
          rowKey={(r, i) => `${r.scanner_asset_tag}-${r.check_date}-${i}`}
        />
      </section>
    </main>
  );
}
