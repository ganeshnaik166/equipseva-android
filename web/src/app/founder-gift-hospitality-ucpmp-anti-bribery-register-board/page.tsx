import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { compliance_status: string; declarations: number; pct: number };
type DeptRow = {
  department: string;
  total_declarations: number;
  compliant: number;
  approval_pending: number;
  late_declaration: number;
  threshold_breach: number;
  undeclared_found: number;
  compliance_pct: number;
};
type MatrixRow = {
  direction: string;
  compliance_status: string;
  declarations: number;
  avg_gift_value_rupees: number;
};
type TrendRow = {
  period_month: string;
  declarations: number;
  compliant: number;
  non_compliant: number;
  threshold_breaches: number;
  avg_declared_within_days: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_financial_exposure_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_financial_exposure_rupees: number;
  pct: number;
};
type BreachRow = {
  counterparty_type: string;
  breaches: number;
  avg_gift_value_rupees: number;
  avg_threshold_rupees: number;
  hcp_involved_count: number;
};
type RiskRow = {
  declaration_ref: string;
  department: string;
  period_month: string;
  declared_by: string;
  counterparty_type: string;
  direction: string;
  gift_value_rupees: number;
  threshold_rupees: number;
  compliance_status: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    deptRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    breachRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3714_compliance_status_rollup'),
    supabase.rpc('founder_r3714_department_scorecard'),
    supabase.rpc('founder_r3714_direction_status_matrix'),
    supabase.rpc('founder_r3714_monthly_declaration_trend'),
    supabase.rpc('founder_r3714_capa_status_board'),
    supabase.rpc('founder_r3714_root_cause_pareto'),
    supabase.rpc('founder_r3714_threshold_breach_digest'),
    supabase.rpc('founder_r3714_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const deptRows: DeptRow[] = (deptRes.data as DeptRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const breachRows: BreachRow[] = (breachRes.data as BreachRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'declarations', header: 'Declarations' },
    { key: 'pct', header: 'Share %' },
  ];

  const deptCols: Column<DeptRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'total_declarations', header: 'Declarations' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'approval_pending', header: 'Approval Pending' },
    { key: 'late_declaration', header: 'Late Declaration' },
    { key: 'threshold_breach', header: 'Threshold Breach' },
    { key: 'undeclared_found', header: 'Undeclared Found' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'direction', header: 'Direction' },
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'declarations', header: 'Declarations' },
    { key: 'avg_gift_value_rupees', header: 'Avg Gift Value (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'declarations', header: 'Declarations' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'non_compliant', header: 'Non-Compliant' },
    { key: 'threshold_breaches', header: 'Threshold Breaches' },
    { key: 'avg_declared_within_days', header: 'Avg Declared Within (days)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_financial_exposure_rupees', header: 'Avg Exposure (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_financial_exposure_rupees', header: 'Total Exposure (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const breachCols: Column<BreachRow>[] = [
    { key: 'counterparty_type', header: 'Counterparty Type' },
    { key: 'breaches', header: 'Breaches' },
    { key: 'avg_gift_value_rupees', header: 'Avg Gift Value (INR)' },
    { key: 'avg_threshold_rupees', header: 'Avg Threshold (INR)' },
    { key: 'hcp_involved_count', header: 'HCP Involved' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'declaration_ref', header: 'Declaration Ref' },
    { key: 'department', header: 'Department' },
    { key: 'period_month', header: 'Month' },
    { key: 'declared_by', header: 'Declared By' },
    { key: 'counterparty_type', header: 'Counterparty Type' },
    { key: 'direction', header: 'Direction' },
    { key: 'gift_value_rupees', header: 'Gift Value (INR)' },
    { key: 'threshold_rupees', header: 'Threshold (INR)' },
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Gift &amp; Hospitality (UCPMP) Anti-Bribery Register Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Gift &amp; hospitality declarations (UCPMP &amp; anti-bribery) register — employee
        declarations of gifts and hospitality to/from HCPs &amp; officials, tracked by counterparty
        type &times; declared value &times; threshold &times; approval status &times; declaration
        timeliness &times; direction &amp; CAPA closure. Founder-gated view: compliance-status
        rollups, department scorecards, root-cause pareto, and a high-risk undeclared/threshold-breach
        queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No declarations logged yet."
          rowKey={(r, i) => String(r.compliance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Department scorecard</h2>
        <DataTable
          rows={deptRows}
          columns={deptCols}
          emptyMessage="No department rollups."
          rowKey={(r, i) => String(r.department ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Direction &times; compliance status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No declarations by direction."
          rowKey={(r, i) => `${r.direction}-${r.compliance_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly declaration trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.period_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Threshold-breach digest</h2>
        <DataTable
          rows={breachRows}
          columns={breachCols}
          emptyMessage="No threshold-breach data."
          rowKey={(r, i) => String(r.counterparty_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk declaration queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk declarations."
          rowKey={(r, i) => `${r.declaration_ref}-${i}`}
        />
      </section>
    </main>
  );
}
