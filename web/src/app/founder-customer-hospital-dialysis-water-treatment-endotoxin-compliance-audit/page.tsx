import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { overall_verdict: string; tests: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_tests: number;
  compliant: number;
  action_required: number;
  non_compliant: number;
  endotoxin_exceed: number;
  tvc_exceed: number;
  chlorine_exceed: number;
  compliance_pct: number;
};
type PointRow = {
  sample_point: string;
  test_standard: string;
  tests: number;
  compliant: number;
  avg_endotoxin: number;
};
type TrendRow = {
  test_date: string;
  compliant: number;
  action_required: number;
  non_compliant: number;
  endotoxin_exceed: number;
  tvc_exceed: number;
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
  sample_ref: string;
  sample_point: string;
  test_date: string;
  overall_verdict: string;
  endotoxin_verdict: string | null;
  tvc_verdict: string | null;
  chlorine_verdict: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    pointRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3138_verdict_rollup'),
    supabase.rpc('founder_r3138_hospital_scorecard'),
    supabase.rpc('founder_r3138_sample_point_matrix'),
    supabase.rpc('founder_r3138_water_daily_trend'),
    supabase.rpc('founder_r3138_capa_status_board'),
    supabase.rpc('founder_r3138_root_cause_pareto'),
    supabase.rpc('founder_r3138_regulatory_impact_digest'),
    supabase.rpc('founder_r3138_high_risk_samples'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const pointRows: PointRow[] = (pointRes.data as PointRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'overall_verdict', header: 'Verdict' },
    { key: 'tests', header: 'Tests' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_tests', header: 'Tests' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'action_required', header: 'Action Req.' },
    { key: 'non_compliant', header: 'Non-Compliant' },
    { key: 'endotoxin_exceed', header: 'Endotoxin Exceed' },
    { key: 'tvc_exceed', header: 'TVC Exceed' },
    { key: 'chlorine_exceed', header: 'Chlorine Exceed' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const pointCols: Column<PointRow>[] = [
    { key: 'sample_point', header: 'Sample Point' },
    { key: 'test_standard', header: 'Standard' },
    { key: 'tests', header: 'Tests' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'avg_endotoxin', header: 'Avg Endotoxin EU/mL' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'test_date', header: 'Date' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'action_required', header: 'Action Req.' },
    { key: 'non_compliant', header: 'Non-Compliant' },
    { key: 'endotoxin_exceed', header: 'Endotoxin Exceed' },
    { key: 'tvc_exceed', header: 'TVC Exceed' },
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
    { key: 'sample_ref', header: 'Sample' },
    { key: 'sample_point', header: 'Point' },
    { key: 'test_date', header: 'Date' },
    { key: 'overall_verdict', header: 'Verdict' },
    { key: 'endotoxin_verdict', header: 'Endotoxin' },
    { key: 'tvc_verdict', header: 'TVC' },
    { key: 'chlorine_verdict', header: 'Chlorine' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Dialysis Machine Water-Treatment &amp; Endotoxin Compliance Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        RO water loop test log — sample point &times; endotoxin EU/mL &times; TVC CFU &times;
        chlorine/chloramine &times; hardness &times; conductivity &amp; CAPA closure. Founder-gated
        view: sample verdicts, hospital scorecards, root-cause pareto, and regulatory-impact digest
        across NABH, CDSCO &amp; AAMI dialysis-water surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Overall verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No water samples logged yet."
          rowKey={(r, i) => String(r.overall_verdict ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Sample point &times; standard matrix</h2>
        <DataTable
          rows={pointRows}
          columns={pointCols}
          emptyMessage="No samples by point."
          rowKey={(r, i) => `${r.sample_point}-${r.test_standard}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily compliance trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.test_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk samples queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk samples."
          rowKey={(r, i) => `${r.sample_ref}-${r.test_date}-${i}`}
        />
      </section>
    </main>
  );
}
