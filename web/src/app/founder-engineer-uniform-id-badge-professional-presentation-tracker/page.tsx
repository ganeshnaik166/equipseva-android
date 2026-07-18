import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { presentation_verdict: string; checks: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_checks: number;
  exemplary: number;
  critical_violations: number;
  uniform_lapses: number;
  badge_lapses: number;
  avg_perception: number;
  compliance_pct: number;
};
type MatrixRow = {
  check_source: string;
  presentation_verdict: string;
  checks: number;
  avg_perception: number;
};
type TrendRow = {
  check_date: string;
  checks: number;
  uniform_ok: number;
  badge_ok: number;
  grooming_pass: number;
  avg_perception: number;
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
  engineer_code: string;
  check_date: string;
  check_source: string;
  presentation_verdict: string;
  customer_perception_score: number;
  id_badge_status: string;
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
    supabase.rpc('founder_r3240_verdict_rollup'),
    supabase.rpc('founder_r3240_hospital_scorecard'),
    supabase.rpc('founder_r3240_source_verdict_matrix'),
    supabase.rpc('founder_r3240_daily_trend'),
    supabase.rpc('founder_r3240_capa_status_board'),
    supabase.rpc('founder_r3240_root_cause_pareto'),
    supabase.rpc('founder_r3240_regulatory_impact_digest'),
    supabase.rpc('founder_r3240_high_risk_queue'),
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
    { key: 'presentation_verdict', header: 'Verdict' },
    { key: 'checks', header: 'Checks' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_checks', header: 'Checks' },
    { key: 'exemplary', header: 'Exemplary' },
    { key: 'critical_violations', header: 'Critical' },
    { key: 'uniform_lapses', header: 'Uniform Lapses' },
    { key: 'badge_lapses', header: 'Badge Lapses' },
    { key: 'avg_perception', header: 'Avg Perception' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'check_source', header: 'Check Source' },
    { key: 'presentation_verdict', header: 'Verdict' },
    { key: 'checks', header: 'Checks' },
    { key: 'avg_perception', header: 'Avg Perception' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'check_date', header: 'Date' },
    { key: 'checks', header: 'Checks' },
    { key: 'uniform_ok', header: 'Uniform OK' },
    { key: 'badge_ok', header: 'Badge OK' },
    { key: 'grooming_pass', header: 'Grooming OK' },
    { key: 'avg_perception', header: 'Avg Perception' },
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
    { key: 'engineer_code', header: 'Code' },
    { key: 'check_date', header: 'Date' },
    { key: 'check_source', header: 'Source' },
    { key: 'presentation_verdict', header: 'Verdict' },
    { key: 'customer_perception_score', header: 'Perception' },
    { key: 'id_badge_status', header: 'Badge' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Uniform, ID-Badge &amp; Professional-Presentation Compliance Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Presentation checks — check source &times; uniform &times; ID badge &times; grooming &times;
        tool bag &times; vehicle branding &times; customer perception &amp; CAPA closure.
        Founder-gated view: verdict distribution, hospital scorecards, root-cause pareto,
        and regulatory-impact digest across brand &amp; hospital-access surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Presentation verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No presentation checks logged yet."
          rowKey={(r, i) => String(r.presentation_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital presentation scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Check source &times; verdict matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No checks by source."
          rowKey={(r, i) => `${r.check_source}-${r.presentation_verdict}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily presentation trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk presentation queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk checks."
          rowKey={(r, i) => `${r.engineer_code}-${r.check_date}-${i}`}
        />
      </section>
    </main>
  );
}
