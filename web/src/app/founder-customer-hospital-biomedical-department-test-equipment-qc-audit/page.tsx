import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { tool_verdict: string; tools: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_checks: number;
  trusted: number;
  due_soon: number;
  overdue_untrusted: number;
  accuracy_review: number;
  retire: number;
  trusted_pct: number;
};
type MatrixRow = {
  tool_type: string;
  accuracy_verification_ok: string;
  checks: number;
  trusted: number;
  avg_days_to_cal_due: number;
};
type TrendRow = {
  check_date: string;
  checks: number;
  trusted: number;
  overdue_untrusted: number;
  accuracy_issues: number;
  self_test_fail: number;
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
  tool_code: string;
  tool_type: string;
  check_date: string;
  tool_verdict: string;
  accuracy_verification_ok: string | null;
  calibration_traceable: boolean | null;
  days_to_cal_due: number | null;
  physical_condition: string | null;
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
    supabase.rpc('founder_r3371_tool_verdict_rollup'),
    supabase.rpc('founder_r3371_hospital_scorecard'),
    supabase.rpc('founder_r3371_tool_type_accuracy_matrix'),
    supabase.rpc('founder_r3371_daily_check_trend'),
    supabase.rpc('founder_r3371_capa_status_board'),
    supabase.rpc('founder_r3371_root_cause_pareto'),
    supabase.rpc('founder_r3371_regulatory_impact_digest'),
    supabase.rpc('founder_r3371_high_risk_queue'),
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
    { key: 'tool_verdict', header: 'Tool Verdict' },
    { key: 'tools', header: 'Tools' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_checks', header: 'Checks' },
    { key: 'trusted', header: 'In-Cal Trusted' },
    { key: 'due_soon', header: 'Cal Due Soon' },
    { key: 'overdue_untrusted', header: 'Overdue Untrusted' },
    { key: 'accuracy_review', header: 'Accuracy Review' },
    { key: 'retire', header: 'Retire' },
    { key: 'trusted_pct', header: 'Trusted %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'tool_type', header: 'Tool Type' },
    { key: 'accuracy_verification_ok', header: 'Accuracy Verification' },
    { key: 'checks', header: 'Checks' },
    { key: 'trusted', header: 'Trusted' },
    { key: 'avg_days_to_cal_due', header: 'Avg Days to Cal-Due' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'check_date', header: 'Date' },
    { key: 'checks', header: 'Checks' },
    { key: 'trusted', header: 'Trusted' },
    { key: 'overdue_untrusted', header: 'Overdue Untrusted' },
    { key: 'accuracy_issues', header: 'Accuracy Issues' },
    { key: 'self_test_fail', header: 'Self-Test Fail' },
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
    { key: 'tool_code', header: 'Tool' },
    { key: 'tool_type', header: 'Type' },
    { key: 'check_date', header: 'Date' },
    { key: 'tool_verdict', header: 'Verdict' },
    { key: 'accuracy_verification_ok', header: 'Accuracy' },
    { key: 'calibration_traceable', header: 'Cal Traceable' },
    { key: 'days_to_cal_due', header: 'Days to Cal-Due' },
    { key: 'physical_condition', header: 'Condition' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Biomedical-Engineering Department Test-Equipment QC Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Biomed test-tool QA log — the hospital biomed dept&apos;s own analyzers (defibrillator,
        ESU, electrical-safety, patient-simulator, infusion-pump, SpO2 &amp; NIBP simulators) must
        themselves stay calibrated to be trusted. Tool type &times; self-test &times; calibration
        traceability &times; cal-due window &times; accuracy verification &times; reference
        cross-check &times; firmware &times; physical condition &amp; CAPA closure. Founder-gated
        view: tool verdicts, hospital scorecards, root-cause pareto, and regulatory-impact digest
        across NABH, NABL &amp; ISO-13485 surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Tool verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No QC checks logged yet."
          rowKey={(r, i) => String(r.tool_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital QC scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Tool type &times; accuracy-verification matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No checks by tool type."
          rowKey={(r, i) => `${r.tool_type}-${r.accuracy_verification_ok}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily QC check trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk tool queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk tools."
          rowKey={(r, i) => `${r.tool_code}-${r.check_date}-${i}`}
        />
      </section>
    </main>
  );
}
