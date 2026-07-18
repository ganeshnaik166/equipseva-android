import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { escalation_verdict: string; escalations: number; pct: number };
type EngRow = {
  engineer_name: string;
  total_escalations: number;
  saved_before_breach: number;
  saved_after_breach: number;
  customers_lost: number;
  avg_response_min: number;
  save_rate_pct: number;
  customer_retention_pct: number;
};
type MatrixRow = {
  escalation_source: string;
  severity: string;
  escalations: number;
  saved: number;
  avg_response_min: number;
};
type TrendRow = {
  escalation_date: string;
  escalations: number;
  saved: number;
  breached: number;
  avg_response_min: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_or_escalated: number;
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
  escalation_code: string;
  escalation_date: string;
  escalation_source: string;
  severity: string;
  response_time_minutes: number;
  escalation_verdict: string;
  de_escalation_quality: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    engRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3200_verdict_rollup'),
    supabase.rpc('founder_r3200_engineer_scorecard'),
    supabase.rpc('founder_r3200_source_severity_matrix'),
    supabase.rpc('founder_r3200_daily_trend'),
    supabase.rpc('founder_r3200_capa_status_board'),
    supabase.rpc('founder_r3200_root_cause_pareto'),
    supabase.rpc('founder_r3200_regulatory_impact_digest'),
    supabase.rpc('founder_r3200_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const engRows: EngRow[] = (engRes.data as EngRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'escalation_verdict', header: 'Verdict' },
    { key: 'escalations', header: 'Escalations' },
    { key: 'pct', header: 'Share %' },
  ];

  const engCols: Column<EngRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'total_escalations', header: 'Escalations' },
    { key: 'saved_before_breach', header: 'Saved Pre-Breach' },
    { key: 'saved_after_breach', header: 'Saved Post-Breach' },
    { key: 'customers_lost', header: 'Customers Lost' },
    { key: 'avg_response_min', header: 'Avg Response (min)' },
    { key: 'save_rate_pct', header: 'Save Rate %' },
    { key: 'customer_retention_pct', header: 'Retention %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'escalation_source', header: 'Source' },
    { key: 'severity', header: 'Severity' },
    { key: 'escalations', header: 'Escalations' },
    { key: 'saved', header: 'Saved Pre-Breach' },
    { key: 'avg_response_min', header: 'Avg Response (min)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'escalation_date', header: 'Date' },
    { key: 'escalations', header: 'Escalations' },
    { key: 'saved', header: 'Saved Pre-Breach' },
    { key: 'breached', header: 'Breached' },
    { key: 'avg_response_min', header: 'Avg Response (min)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_or_escalated', header: 'Overdue / Escalated' },
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
    { key: 'escalation_code', header: 'Code' },
    { key: 'escalation_date', header: 'Date' },
    { key: 'escalation_source', header: 'Source' },
    { key: 'severity', header: 'Severity' },
    { key: 'response_time_minutes', header: 'Response (min)' },
    { key: 'escalation_verdict', header: 'Verdict' },
    { key: 'de_escalation_quality', header: 'De-escalation' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Escalation-Handling &amp; SLA-Breach Save-Rate Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Escalation log &mdash; source &times; severity &times; response minutes &times;
        resolved-before-breach &times; customer retained &times; de-escalation quality &amp; CAPA closure.
        Founder-gated view: verdict rollups, engineer save-rate scorecards, root-cause pareto,
        and regulatory-impact digest across contract-penalty &amp; patient-safety surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Escalation verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No escalations logged yet."
          rowKey={(r, i) => String(r.escalation_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer save-rate scorecard</h2>
        <DataTable
          rows={engRows}
          columns={engCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Source &times; severity matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No escalations by source."
          rowKey={(r, i) => `${r.escalation_source}-${r.severity}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily escalation trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.escalation_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk escalation queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk escalations."
          rowKey={(r, i) => `${r.escalation_code}-${r.escalation_date}-${i}`}
        />
      </section>
    </main>
  );
}
