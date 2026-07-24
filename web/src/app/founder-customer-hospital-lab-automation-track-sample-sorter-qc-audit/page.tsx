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
  routing_issue: number;
  lis_issue: number;
  calibration_overdue: number;
  pass_pct: number;
};
type MatrixRow = { system_type: string; lab_section: string; checks: number; passed: number; failed: number; avg_barcode_rate: number };
type TrendRow = { check_date: string; checks: number; passed: number; failed: number; routing_issue: number; lis_issue: number };
type CapaRow = { capa_status: string; findings: number; avg_cost_rupees: number; overdue_flag: number };
type CauseRow = { root_cause: string; occurrences: number; total_cost_rupees: number; pct: number };
type RegRow = { regulatory_impact: string; findings: number; open_findings: number; total_cost_rupees: number };
type RiskRow = {
  hospital_name: string;
  unit_code: string;
  system_type: string;
  lab_section: string;
  check_date: string;
  qc_verdict: string;
  decap_recap_ok: string;
  centrifuge_balance_ok: string;
  barcode_read_rate_pct: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [verdictRes, scoreRes, matrixRes, trendRes, capaRes, causeRes, regRes, riskRes] = await Promise.all([
    supabase.rpc('founder_r3394_qc_verdict_rollup'),
    supabase.rpc('founder_r3394_hospital_scorecard'),
    supabase.rpc('founder_r3394_system_section_matrix'),
    supabase.rpc('founder_r3394_daily_qc_trend'),
    supabase.rpc('founder_r3394_capa_status_board'),
    supabase.rpc('founder_r3394_root_cause_pareto'),
    supabase.rpc('founder_r3394_regulatory_impact_digest'),
    supabase.rpc('founder_r3394_high_risk_queue'),
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
    { key: 'routing_issue', header: 'Routing Issue' },
    { key: 'lis_issue', header: 'LIS Issue' },
    { key: 'calibration_overdue', header: 'Cal Overdue' },
    { key: 'pass_pct', header: 'Pass %' },
  ];
  const matrixCols: Column<MatrixRow>[] = [
    { key: 'system_type', header: 'System Type' },
    { key: 'lab_section', header: 'Lab Section' },
    { key: 'checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'avg_barcode_rate', header: 'Avg Barcode %' },
  ];
  const trendCols: Column<TrendRow>[] = [
    { key: 'check_date', header: 'Date' },
    { key: 'checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'routing_issue', header: 'Routing Issue' },
    { key: 'lis_issue', header: 'LIS Issue' },
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
    { key: 'unit_code', header: 'Module' },
    { key: 'system_type', header: 'System Type' },
    { key: 'lab_section', header: 'Lab Section' },
    { key: 'check_date', header: 'Date' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'decap_recap_ok', header: 'Decap/Recap' },
    { key: 'centrifuge_balance_ok', header: 'Centrifuge' },
    { key: 'barcode_read_rate_pct', header: 'Barcode %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Laboratory-Automation Track (TLA) &amp; Sample-Sorter QC Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Total-lab-automation modules &mdash; track conveyor &times; sorter &times; centrifuge &times; aliquoter
        &times; decapper/recapper &times; throughput &times; routing accuracy &times; barcode read &times; STAT
        routing &times; LIS connectivity &amp; CAPA. Founder-gated view: verdict rollup, hospital scorecard,
        system &times; section matrix, and high-risk module queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. QC verdict distribution</h2>
        <DataTable rows={verdictRows} columns={verdictCols} emptyMessage="No modules checked yet." rowKey={(r, i) => String(r.qc_verdict ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital QC scorecard</h2>
        <DataTable rows={scoreRows} columns={scoreCols} emptyMessage="No hospital rollups." rowKey={(r, i) => String(r.hospital_name ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. System-type &times; lab-section matrix</h2>
        <DataTable rows={matrixRows} columns={matrixCols} emptyMessage="No matrix data." rowKey={(r, i) => `${r.system_type}-${r.lab_section}-${i}`} />
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk module queue</h2>
        <DataTable rows={riskRows} columns={riskCols} emptyMessage="No high-risk modules." rowKey={(r, i) => `${r.unit_code}-${i}`} />
      </section>
    </main>
  );
}
