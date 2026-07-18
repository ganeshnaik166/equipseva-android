import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { aer_verdict: string; cycles: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_cycles: number;
  released: number;
  quarantined: number;
  recalls: number;
  leak_fail: number;
  mrc_fail: number;
  culture_positive: number;
  compliance_pct: number;
};
type MatrixRow = {
  scope_type: string;
  procedure_type: string;
  cycles: number;
  released: number;
  avg_contact_time: number;
};
type TrendRow = {
  cycle_date: string;
  cycles: number;
  leak_fail: number;
  mrc_fail: number;
  culture_positive: number;
  released: number;
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
  endoscopy_suite_code: string;
  scope_asset_tag: string;
  scope_type: string;
  cycle_date: string;
  aer_verdict: string;
  leak_test_result: string | null;
  mrc_test_result: string | null;
  culture_result: string | null;
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
    supabase.rpc('founder_r3159_verdict_rollup'),
    supabase.rpc('founder_r3159_hospital_scorecard'),
    supabase.rpc('founder_r3159_scope_procedure_matrix'),
    supabase.rpc('founder_r3159_reprocessing_daily_trend'),
    supabase.rpc('founder_r3159_capa_status_board'),
    supabase.rpc('founder_r3159_root_cause_pareto'),
    supabase.rpc('founder_r3159_regulatory_impact_digest'),
    supabase.rpc('founder_r3159_high_risk_queue'),
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
    { key: 'aer_verdict', header: 'Verdict' },
    { key: 'cycles', header: 'Cycles' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_cycles', header: 'Cycles' },
    { key: 'released', header: 'Released' },
    { key: 'quarantined', header: 'Quarantined' },
    { key: 'recalls', header: 'Recalls' },
    { key: 'leak_fail', header: 'Leak Fail' },
    { key: 'mrc_fail', header: 'MRC Fail' },
    { key: 'culture_positive', header: 'Culture+' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'scope_type', header: 'Scope Type' },
    { key: 'procedure_type', header: 'Procedure' },
    { key: 'cycles', header: 'Cycles' },
    { key: 'released', header: 'Released' },
    { key: 'avg_contact_time', header: 'Avg Contact (min)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'cycle_date', header: 'Date' },
    { key: 'cycles', header: 'Cycles' },
    { key: 'leak_fail', header: 'Leak Fail' },
    { key: 'mrc_fail', header: 'MRC Fail' },
    { key: 'culture_positive', header: 'Culture+' },
    { key: 'released', header: 'Released' },
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
    { key: 'endoscopy_suite_code', header: 'Suite' },
    { key: 'scope_asset_tag', header: 'Scope' },
    { key: 'scope_type', header: 'Type' },
    { key: 'cycle_date', header: 'Date' },
    { key: 'aer_verdict', header: 'Verdict' },
    { key: 'leak_test_result', header: 'Leak' },
    { key: 'mrc_test_result', header: 'MRC' },
    { key: 'culture_result', header: 'Culture' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Endoscope Reprocessing (AER) Cycle &amp; Traceability Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Endoscope reprocessing log — scope type &times; procedure &times; leak test &times; manual clean &times;
        disinfectant (peracetic / OPA / glutaraldehyde) &times; MRC concentration &times; contact time &times; cycle
        result &times; culture &amp; CAPA closure. Founder-gated view: verdict distribution, hospital scorecards,
        root-cause pareto, and regulatory-impact digest across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. AER verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No reprocessing cycles logged yet."
          rowKey={(r, i) => String(r.aer_verdict ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Scope type &times; procedure matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No cycles by scope."
          rowKey={(r, i) => `${r.scope_type}-${r.procedure_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Reprocessing daily trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.cycle_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk scope queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk scopes."
          rowKey={(r, i) => `${r.scope_asset_tag}-${r.cycle_date}-${i}`}
        />
      </section>
    </main>
  );
}
