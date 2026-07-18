import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { audit_verdict: string; audits: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  passed: number;
  conditional: number;
  failed: number;
  removed: number;
  avg_gas_purity_pct: number;
  avg_flow_error_pct: number;
  compliance_pct: number;
};
type SourceRow = {
  co2_source: string;
  purity_grade: string;
  audits: number;
  passed: number;
  avg_purity_pct: number;
};
type TrendRow = {
  audit_date: string;
  audits: number;
  passed: number;
  failed: number;
  flow_out_of_tolerance: number;
  avg_flow_error_pct: number;
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
  ot_room_code: string;
  insufflator_asset_tag: string;
  audit_date: string;
  audit_verdict: string;
  flow_calibration_verdict: string | null;
  overpressure_relief_result: string | null;
  heater_function: string | null;
  filter_status: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    sourceRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3234_audit_verdict_rollup'),
    supabase.rpc('founder_r3234_hospital_scorecard'),
    supabase.rpc('founder_r3234_source_purity_matrix'),
    supabase.rpc('founder_r3234_daily_audit_trend'),
    supabase.rpc('founder_r3234_capa_status_board'),
    supabase.rpc('founder_r3234_root_cause_pareto'),
    supabase.rpc('founder_r3234_regulatory_impact_digest'),
    supabase.rpc('founder_r3234_high_risk_units'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const sourceRows: SourceRow[] = (sourceRes.data as SourceRow[]) ?? [];
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
    { key: 'conditional', header: 'Conditional' },
    { key: 'failed', header: 'Fail' },
    { key: 'removed', header: 'Removed' },
    { key: 'avg_gas_purity_pct', header: 'Avg Purity %' },
    { key: 'avg_flow_error_pct', header: 'Avg Flow Err %' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const sourceCols: Column<SourceRow>[] = [
    { key: 'co2_source', header: 'CO2 Source' },
    { key: 'purity_grade', header: 'Purity Grade' },
    { key: 'audits', header: 'Audits' },
    { key: 'passed', header: 'Pass' },
    { key: 'avg_purity_pct', header: 'Avg Purity %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'passed', header: 'Pass' },
    { key: 'failed', header: 'Fail' },
    { key: 'flow_out_of_tolerance', header: 'Flow OOT' },
    { key: 'avg_flow_error_pct', header: 'Avg Flow Err %' },
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
    { key: 'ot_room_code', header: 'OT' },
    { key: 'insufflator_asset_tag', header: 'Asset' },
    { key: 'audit_date', header: 'Date' },
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'flow_calibration_verdict', header: 'Flow Cal' },
    { key: 'overpressure_relief_result', header: 'OP Relief' },
    { key: 'heater_function', header: 'Heater' },
    { key: 'filter_status', header: 'Filter' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Laparoscopic Insufflator CO2 Purity &amp; Flow Calibration Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Insufflator QA log &mdash; CO2 source &times; gas purity &times; set/measured flow &times;
        flow error &times; pressure-limit &times; over-pressure relief &times; heater &times; filter &amp; CAPA closure.
        Founder-gated view: audit verdicts, hospital scorecards, source-purity matrix, root-cause pareto,
        and regulatory-impact digest across NABH &amp; CDSCO surfaces.
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital compliance scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. CO2 source &times; purity grade matrix</h2>
        <DataTable
          rows={sourceRows}
          columns={sourceCols}
          emptyMessage="No source-purity rollups."
          rowKey={(r, i) => `${r.co2_source}-${r.purity_grade}-${i}`}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk units queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk units."
          rowKey={(r, i) => `${r.insufflator_asset_tag}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
