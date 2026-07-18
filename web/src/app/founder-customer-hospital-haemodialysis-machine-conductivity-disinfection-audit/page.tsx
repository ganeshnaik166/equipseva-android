import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { audit_verdict: string; audits: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  fit_for_use: number;
  out_of_service: number;
  blood_leak_fails: number;
  air_detector_fails: number;
  disinfection_incomplete: number;
  avg_conductivity: number;
  compliance_pct: number;
};
type CycleMatrixRow = {
  disinfection_cycle_type: string;
  audits: number;
  completed: number;
  fit_for_use: number;
  avg_conductivity: number;
};
type TrendRow = {
  audit_date: string;
  audits: number;
  fit_for_use: number;
  out_of_service: number;
  detector_fails: number;
  avg_conductivity: number;
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
  dialysis_unit_code: string;
  machine_asset_tag: string;
  audit_date: string;
  audit_verdict: string;
  blood_leak_detector_test: string | null;
  air_detector_test: string | null;
  heparin_pump_verdict: string | null;
  disinfection_cycle_type: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    cycleRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3194_audit_verdict_rollup'),
    supabase.rpc('founder_r3194_hospital_scorecard'),
    supabase.rpc('founder_r3194_disinfection_cycle_matrix'),
    supabase.rpc('founder_r3194_daily_audit_trend'),
    supabase.rpc('founder_r3194_capa_status_board'),
    supabase.rpc('founder_r3194_root_cause_pareto'),
    supabase.rpc('founder_r3194_regulatory_impact_digest'),
    supabase.rpc('founder_r3194_high_risk_machines'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const cycleRows: CycleMatrixRow[] = (cycleRes.data as CycleMatrixRow[]) ?? [];
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
    { key: 'fit_for_use', header: 'Fit for Use' },
    { key: 'out_of_service', header: 'Out of Service' },
    { key: 'blood_leak_fails', header: 'Blood-Leak Fails' },
    { key: 'air_detector_fails', header: 'Air-Det Fails' },
    { key: 'disinfection_incomplete', header: 'Disinfect Incomplete' },
    { key: 'avg_conductivity', header: 'Avg mS/cm' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const cycleCols: Column<CycleMatrixRow>[] = [
    { key: 'disinfection_cycle_type', header: 'Cycle Type' },
    { key: 'audits', header: 'Audits' },
    { key: 'completed', header: 'Completed' },
    { key: 'fit_for_use', header: 'Fit for Use' },
    { key: 'avg_conductivity', header: 'Avg mS/cm' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'fit_for_use', header: 'Fit for Use' },
    { key: 'out_of_service', header: 'Out of Service' },
    { key: 'detector_fails', header: 'Detector Fails' },
    { key: 'avg_conductivity', header: 'Avg mS/cm' },
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
    { key: 'dialysis_unit_code', header: 'Unit' },
    { key: 'machine_asset_tag', header: 'Asset' },
    { key: 'audit_date', header: 'Date' },
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'blood_leak_detector_test', header: 'Blood-Leak' },
    { key: 'air_detector_test', header: 'Air Det' },
    { key: 'heparin_pump_verdict', header: 'Heparin Pump' },
    { key: 'disinfection_cycle_type', header: 'Disinfection' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Haemodialysis Machine Conductivity &amp; Disinfection-Cycle Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        HD machine QA log &mdash; dialysate conductivity mS/cm &times; temperature &times;
        blood-leak &amp; air detector tests &times; heparin-pump accuracy &times; disinfection cycle
        (heat / citric / chemical) &amp; CAPA closure. Founder-gated view: audit verdicts, hospital
        scorecards, root-cause pareto, and regulatory-impact digest across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Audit verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No machine audits logged yet."
          rowKey={(r, i) => String(r.audit_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital compliance scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Disinfection cycle type matrix</h2>
        <DataTable
          rows={cycleRows}
          columns={cycleCols}
          emptyMessage="No disinfection-cycle rollups."
          rowKey={(r, i) => `${r.disinfection_cycle_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily audit trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.audit_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk machines queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk machines."
          rowKey={(r, i) => `${r.machine_asset_tag}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
