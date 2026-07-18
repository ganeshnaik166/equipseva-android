import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { incident_verdict: string; incidents: number; pct: number };
type EngRow = {
  engineer_name: string;
  total_incidents: number;
  near_misses: number;
  lost_time_cases: number;
  total_lost_days: number;
  ppe_compliant: number;
  on_time_reports: number;
  ppe_compliance_pct: number;
};
type MatrixRow = {
  incident_type: string;
  severity: string;
  incidents: number;
  ppe_gaps: number;
  avg_lost_days: number;
};
type TrendRow = {
  incident_date: string;
  incidents: number;
  near_misses: number;
  lost_time_cases: number;
  ppe_gaps: number;
  late_reports: number;
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
  incident_code: string;
  incident_date: string;
  incident_type: string;
  severity: string;
  ppe_worn: string;
  lost_time_days: number;
  incident_verdict: string;
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
    supabase.rpc('founder_r3224_incident_verdict_rollup'),
    supabase.rpc('founder_r3224_engineer_scorecard'),
    supabase.rpc('founder_r3224_type_severity_matrix'),
    supabase.rpc('founder_r3224_daily_trend'),
    supabase.rpc('founder_r3224_capa_status_board'),
    supabase.rpc('founder_r3224_root_cause_pareto'),
    supabase.rpc('founder_r3224_regulatory_impact_digest'),
    supabase.rpc('founder_r3224_high_risk_queue'),
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
    { key: 'incident_verdict', header: 'Verdict' },
    { key: 'incidents', header: 'Incidents' },
    { key: 'pct', header: 'Share %' },
  ];

  const engCols: Column<EngRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'total_incidents', header: 'Incidents' },
    { key: 'near_misses', header: 'Near-Misses' },
    { key: 'lost_time_cases', header: 'Lost-Time Cases' },
    { key: 'total_lost_days', header: 'Lost Days' },
    { key: 'ppe_compliant', header: 'PPE OK' },
    { key: 'on_time_reports', header: 'On-Time Reports' },
    { key: 'ppe_compliance_pct', header: 'PPE %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'incident_type', header: 'Incident Type' },
    { key: 'severity', header: 'Severity' },
    { key: 'incidents', header: 'Incidents' },
    { key: 'ppe_gaps', header: 'PPE Gaps' },
    { key: 'avg_lost_days', header: 'Avg Lost Days' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'incident_date', header: 'Date' },
    { key: 'incidents', header: 'Incidents' },
    { key: 'near_misses', header: 'Near-Misses' },
    { key: 'lost_time_cases', header: 'Lost-Time' },
    { key: 'ppe_gaps', header: 'PPE Gaps' },
    { key: 'late_reports', header: 'Late Reports' },
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
    { key: 'incident_code', header: 'Code' },
    { key: 'incident_date', header: 'Date' },
    { key: 'incident_type', header: 'Type' },
    { key: 'severity', header: 'Severity' },
    { key: 'ppe_worn', header: 'PPE' },
    { key: 'lost_time_days', header: 'Lost Days' },
    { key: 'incident_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Safety-Incident, Near-Miss &amp; PPE-Compliance Field Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field-safety event log &mdash; incident type &times; severity &times; PPE worn &times;
        lost-time days &times; 24h reporting discipline &amp; CAPA closure. Founder-gated view:
        incident verdicts, engineer scorecards, root-cause pareto, and regulatory-impact digest.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Incident verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No incidents logged yet."
          rowKey={(r, i) => String(r.incident_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer safety scorecard</h2>
        <DataTable
          rows={engRows}
          columns={engCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Incident type &times; severity matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No incidents by type."
          rowKey={(r, i) => `${r.incident_type}-${r.severity}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily incident trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.incident_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk incident queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk incidents."
          rowKey={(r, i) => `${r.incident_code}-${i}`}
        />
      </section>
    </main>
  );
}
