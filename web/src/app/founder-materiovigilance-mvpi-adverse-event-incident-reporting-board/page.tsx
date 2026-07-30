import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { report_status: string; reports: number; pct: number };
type EventRow = {
  event_type: string;
  total_reports: number;
  critical: number;
  overdue: number;
  reported_cdsco: number;
  capa_linked_reports: number;
  avg_days_to_report: number;
  total_patients: number;
  cdsco_pct: number;
};
type MatrixRow = {
  event_type: string;
  severity: string;
  reports: number;
  closed: number;
  overdue: number;
  avg_days_to_report: number;
};
type TrendRow = {
  period_month: string;
  reports: number;
  closed: number;
  overdue: number;
  total_patients: number;
  avg_days_to_report: number;
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
type SevRow = {
  severity: string;
  reports: number;
  total_patients: number;
  reported_cdsco: number;
  open_reports: number;
  avg_days_to_report: number;
};
type RiskRow = {
  report_ref: string;
  device_name: string;
  event_type: string;
  severity: string;
  period_month: string;
  report_status: string;
  days_to_report: number;
  patients_affected: number;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    eventRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    sevRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3640_report_status_rollup'),
    supabase.rpc('founder_r3640_event_type_scorecard'),
    supabase.rpc('founder_r3640_event_type_severity_matrix'),
    supabase.rpc('founder_r3640_monthly_incident_trend'),
    supabase.rpc('founder_r3640_capa_status_board'),
    supabase.rpc('founder_r3640_root_cause_pareto'),
    supabase.rpc('founder_r3640_severity_impact_digest'),
    supabase.rpc('founder_r3640_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const eventRows: EventRow[] = (eventRes.data as EventRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const sevRows: SevRow[] = (sevRes.data as SevRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'report_status', header: 'Report Status' },
    { key: 'reports', header: 'Reports' },
    { key: 'pct', header: 'Share %' },
  ];

  const eventCols: Column<EventRow>[] = [
    { key: 'event_type', header: 'Event Type' },
    { key: 'total_reports', header: 'Reports' },
    { key: 'critical', header: 'Critical' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'reported_cdsco', header: 'CDSCO Reported' },
    { key: 'capa_linked_reports', header: 'CAPA Linked' },
    { key: 'avg_days_to_report', header: 'Avg Days to Report' },
    { key: 'total_patients', header: 'Patients Affected' },
    { key: 'cdsco_pct', header: 'CDSCO %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'event_type', header: 'Event Type' },
    { key: 'severity', header: 'Severity' },
    { key: 'reports', header: 'Reports' },
    { key: 'closed', header: 'Closed' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'avg_days_to_report', header: 'Avg Days to Report' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'reports', header: 'Reports' },
    { key: 'closed', header: 'Closed' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'total_patients', header: 'Patients Affected' },
    { key: 'avg_days_to_report', header: 'Avg Days to Report' },
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

  const sevCols: Column<SevRow>[] = [
    { key: 'severity', header: 'Severity' },
    { key: 'reports', header: 'Reports' },
    { key: 'total_patients', header: 'Patients Affected' },
    { key: 'reported_cdsco', header: 'CDSCO Reported' },
    { key: 'open_reports', header: 'Open' },
    { key: 'avg_days_to_report', header: 'Avg Days to Report' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'report_ref', header: 'Report' },
    { key: 'device_name', header: 'Device' },
    { key: 'event_type', header: 'Event Type' },
    { key: 'severity', header: 'Severity' },
    { key: 'period_month', header: 'Month' },
    { key: 'report_status', header: 'Status' },
    { key: 'days_to_report', header: 'Days to Report' },
    { key: 'patients_affected', header: 'Patients' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Materiovigilance (MvPI) Adverse-Event / Incident Reporting Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Materiovigilance Programme of India (MvPI / CDSCO) adverse-event &amp; device-malfunction
        incident register — per report: event type (death, serious injury, malfunction, near miss,
        no harm) &times; severity &times; report status &times; time-to-report &times; patients
        affected &times; CDSCO notification &times; root-cause identification &times; CAPA linkage
        &amp; closure. Founder-gated view: report-status distribution, event-type scorecards,
        root-cause pareto, severity-impact digest and the high-risk queue across FSCA &amp; recall
        surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Report-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No incident reports logged yet."
          rowKey={(r, i) => String(r.report_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Event-type scorecard</h2>
        <DataTable
          rows={eventRows}
          columns={eventCols}
          emptyMessage="No event-type rollups."
          rowKey={(r, i) => String(r.event_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Event-type &times; severity matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No reports by event type."
          rowKey={(r, i) => `${r.event_type}-${r.severity}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly incident trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Severity-impact digest</h2>
        <DataTable
          rows={sevRows}
          columns={sevCols}
          emptyMessage="No severity rollups."
          rowKey={(r, i) => String(r.severity ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk reports."
          rowKey={(r, i) => `${r.report_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
