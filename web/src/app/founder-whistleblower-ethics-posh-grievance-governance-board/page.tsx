import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { case_verdict: string; cases: number; pct: number };
type DeptRow = {
  department_involved: string;
  total_cases: number;
  substantiated: number;
  open_overdue: number;
  escalated: number;
  posh_cases: number;
  anonymous_cases: number;
  closure_pct: number;
};
type MatrixRow = {
  case_category: string;
  reporting_channel: string;
  cases: number;
  substantiated: number;
  avg_days_to_close: number | null;
  anonymous_cases: number;
};
type TrendRow = {
  reported_date: string;
  cases: number;
  substantiated: number;
  open_overdue: number;
  posh_cases: number;
  anonymous_cases: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
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
  actions: number;
  open_actions: number;
  total_cost_rupees: number;
};
type RiskRow = {
  case_ref: string;
  case_category: string;
  department_involved: string;
  severity: string;
  reported_date: string;
  investigation_status: string;
  outcome: string;
  case_verdict: string;
  confidentiality_maintained: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    deptRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3293_case_verdict_rollup'),
    supabase.rpc('founder_r3293_department_scorecard'),
    supabase.rpc('founder_r3293_category_channel_matrix'),
    supabase.rpc('founder_r3293_daily_case_trend'),
    supabase.rpc('founder_r3293_capa_status_board'),
    supabase.rpc('founder_r3293_root_cause_pareto'),
    supabase.rpc('founder_r3293_regulatory_impact_digest'),
    supabase.rpc('founder_r3293_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const deptRows: DeptRow[] = (deptRes.data as DeptRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'case_verdict', header: 'Case Verdict' },
    { key: 'cases', header: 'Cases' },
    { key: 'pct', header: 'Share %' },
  ];

  const deptCols: Column<DeptRow>[] = [
    { key: 'department_involved', header: 'Department' },
    { key: 'total_cases', header: 'Cases' },
    { key: 'substantiated', header: 'Substantiated' },
    { key: 'open_overdue', header: 'Open Overdue' },
    { key: 'escalated', header: 'Escalated' },
    { key: 'posh_cases', header: 'POSH' },
    { key: 'anonymous_cases', header: 'Anonymous' },
    { key: 'closure_pct', header: 'Closure %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'case_category', header: 'Category' },
    { key: 'reporting_channel', header: 'Channel' },
    { key: 'cases', header: 'Cases' },
    { key: 'substantiated', header: 'Substantiated' },
    { key: 'avg_days_to_close', header: 'Avg Days to Close' },
    { key: 'anonymous_cases', header: 'Anonymous' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'reported_date', header: 'Reported Date' },
    { key: 'cases', header: 'Cases' },
    { key: 'substantiated', header: 'Substantiated' },
    { key: 'open_overdue', header: 'Open Overdue' },
    { key: 'posh_cases', header: 'POSH' },
    { key: 'anonymous_cases', header: 'Anonymous' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
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
    { key: 'actions', header: 'Actions' },
    { key: 'open_actions', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'case_ref', header: 'Case Ref' },
    { key: 'case_category', header: 'Category' },
    { key: 'department_involved', header: 'Department' },
    { key: 'severity', header: 'Severity' },
    { key: 'reported_date', header: 'Reported' },
    { key: 'investigation_status', header: 'Status' },
    { key: 'outcome', header: 'Outcome' },
    { key: 'case_verdict', header: 'Verdict' },
    { key: 'confidentiality_maintained', header: 'Confidentiality' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Whistleblower, Ethics-Hotline, POSH &amp; Employee-Grievance Case Governance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated governance log — case category &times; reporting channel &times; severity
        &times; department &times; committee &times; investigation status &times; outcome &times;
        confidentiality &times; board verdict &amp; CAPA closure. Anonymized case handling across
        POSH-IC, ethics-committee, HR-panel &amp; external-investigator tracks: verdict rollups,
        department scorecards, root-cause pareto, and regulatory-impact digest spanning POSH Act
        2013 &amp; Companies Act surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Case verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No governance cases logged yet."
          rowKey={(r, i) => String(r.case_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Department governance scorecard</h2>
        <DataTable
          rows={deptRows}
          columns={deptCols}
          emptyMessage="No department rollups."
          rowKey={(r, i) => String(r.department_involved ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Category &times; reporting-channel matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No cases by category."
          rowKey={(r, i) => `${r.case_category}-${r.reporting_channel}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily case-intake trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.reported_date ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA actions."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk case queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk cases."
          rowKey={(r, i) => `${r.case_ref}-${r.reported_date}-${i}`}
        />
      </section>
    </main>
  );
}
