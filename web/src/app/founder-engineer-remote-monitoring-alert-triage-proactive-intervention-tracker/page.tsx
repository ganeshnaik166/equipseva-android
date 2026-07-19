import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { intervention_verdict: string; alerts: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_alerts: number;
  resolved_remotely: number;
  prevented: number;
  breakdowns: number;
  false_positives: number;
  sla_met: number;
  prevented_pct: number;
};
type MatrixRow = {
  equipment_type: string;
  alert_source: string;
  alerts: number;
  prevented: number;
  breakdowns: number;
  avg_response_hours: number;
};
type TrendRow = {
  alert_date: string;
  alerts: number;
  critical: number;
  breakdowns: number;
  sla_met: number;
  avg_response_hours: number;
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
type ImpactRow = {
  business_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  hospital_name: string;
  device_code: string;
  equipment_type: string;
  alert_date: string;
  alert_severity: string;
  alert_category: string;
  triage_action: string | null;
  intervention_verdict: string;
  response_hours: number | null;
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
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3344_verdict_rollup'),
    supabase.rpc('founder_r3344_hospital_scorecard'),
    supabase.rpc('founder_r3344_equipment_source_matrix'),
    supabase.rpc('founder_r3344_daily_alert_trend'),
    supabase.rpc('founder_r3344_capa_status_board'),
    supabase.rpc('founder_r3344_root_cause_pareto'),
    supabase.rpc('founder_r3344_business_impact_digest'),
    supabase.rpc('founder_r3344_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'intervention_verdict', header: 'Verdict' },
    { key: 'alerts', header: 'Alerts' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_alerts', header: 'Alerts' },
    { key: 'resolved_remotely', header: 'Resolved Remotely' },
    { key: 'prevented', header: 'Prevented On-Site' },
    { key: 'breakdowns', header: 'Breakdowns' },
    { key: 'false_positives', header: 'False Positives' },
    { key: 'sla_met', header: 'SLA Met' },
    { key: 'prevented_pct', header: 'Prevented %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'equipment_type', header: 'Equipment Type' },
    { key: 'alert_source', header: 'Alert Source' },
    { key: 'alerts', header: 'Alerts' },
    { key: 'prevented', header: 'Prevented' },
    { key: 'breakdowns', header: 'Breakdowns' },
    { key: 'avg_response_hours', header: 'Avg Response Hrs' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'alert_date', header: 'Date' },
    { key: 'alerts', header: 'Alerts' },
    { key: 'critical', header: 'Critical' },
    { key: 'breakdowns', header: 'Breakdowns' },
    { key: 'sla_met', header: 'SLA Met' },
    { key: 'avg_response_hours', header: 'Avg Response Hrs' },
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

  const impactCols: Column<ImpactRow>[] = [
    { key: 'business_impact', header: 'Business Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'device_code', header: 'Device' },
    { key: 'equipment_type', header: 'Equipment' },
    { key: 'alert_date', header: 'Date' },
    { key: 'alert_severity', header: 'Severity' },
    { key: 'alert_category', header: 'Category' },
    { key: 'triage_action', header: 'Triage Action' },
    { key: 'intervention_verdict', header: 'Verdict' },
    { key: 'response_hours', header: 'Response Hrs' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Remote-Monitoring Alert Triage &amp; Proactive-Intervention Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Connected-equipment alert ops log — equipment type &times; alert source &times; severity
        &times; alert category &times; SLA triage &times; triage action &times; prevented-breakdown
        &times; intervention verdict &amp; CAPA closure. Telemetry, IoT sensors, and predictive
        models flag component wear, temperature drift, and threshold breaches so engineers can
        intervene before breakdown. Founder-gated view: verdict rollups, hospital scorecards,
        root-cause pareto, and business-impact digest for missed &amp; false alerts.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Intervention verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No alerts logged yet."
          rowKey={(r, i) => String(r.intervention_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital triage scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Equipment type &times; alert source matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No alerts by equipment."
          rowKey={(r, i) => `${r.equipment_type}-${r.alert_source}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily alert trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.alert_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Business-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No business-impact rollups."
          rowKey={(r, i) => String(r.business_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk alert queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk alerts."
          rowKey={(r, i) => `${r.device_code}-${r.alert_date}-${i}`}
        />
      </section>
    </main>
  );
}
