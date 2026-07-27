import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { triage_status: string; complaints: number; pct: number };
type SeverityRow = {
  severity: string;
  total_complaints: number;
  resolved: number;
  unresolved: number;
  escalated: number;
  sla_breached: number;
  avg_response_tat_hours: number;
  avg_resolution_tat_hours: number;
  sla_breach_pct: number;
};
type MatrixRow = {
  severity: string;
  category: string;
  complaints: number;
  sla_breached: number;
  avg_resolution_tat_hours: number;
};
type TrendRow = {
  month: string;
  complaints: number;
  resolved: number;
  escalated: number;
  sla_breached: number;
  avg_resolution_tat_hours: number;
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
type DigestRow = {
  category: string;
  complaints: number;
  sla_breached: number;
  avg_response_tat_hours: number;
  avg_resolution_tat_hours: number;
  max_resolution_tat_hours: number;
  breach_pct: number;
};
type RiskRow = {
  engineer_name: string;
  hospital_name: string;
  complaint_code: string;
  device_model: string;
  severity: string;
  category: string;
  triage_status: string;
  response_tat_hours: number | null;
  resolution_tat_hours: number | null;
  sla_breached: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    severityRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3492_triage_status_rollup'),
    supabase.rpc('founder_r3492_severity_scorecard'),
    supabase.rpc('founder_r3492_severity_category_matrix'),
    supabase.rpc('founder_r3492_monthly_complaint_trend'),
    supabase.rpc('founder_r3492_capa_status_board'),
    supabase.rpc('founder_r3492_root_cause_pareto'),
    supabase.rpc('founder_r3492_tat_impact_digest'),
    supabase.rpc('founder_r3492_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const severityRows: SeverityRow[] = (severityRes.data as SeverityRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'triage_status', header: 'Triage Status' },
    { key: 'complaints', header: 'Complaints' },
    { key: 'pct', header: 'Share %' },
  ];

  const severityCols: Column<SeverityRow>[] = [
    { key: 'severity', header: 'Severity' },
    { key: 'total_complaints', header: 'Complaints' },
    { key: 'resolved', header: 'Resolved' },
    { key: 'unresolved', header: 'Unresolved' },
    { key: 'escalated', header: 'Escalated' },
    { key: 'sla_breached', header: 'SLA Breached' },
    { key: 'avg_response_tat_hours', header: 'Avg Resp TAT (h)' },
    { key: 'avg_resolution_tat_hours', header: 'Avg Resol TAT (h)' },
    { key: 'sla_breach_pct', header: 'Breach %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'severity', header: 'Severity' },
    { key: 'category', header: 'Category' },
    { key: 'complaints', header: 'Complaints' },
    { key: 'sla_breached', header: 'SLA Breached' },
    { key: 'avg_resolution_tat_hours', header: 'Avg Resol TAT (h)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'month', header: 'Month' },
    { key: 'complaints', header: 'Complaints' },
    { key: 'resolved', header: 'Resolved' },
    { key: 'escalated', header: 'Escalated' },
    { key: 'sla_breached', header: 'SLA Breached' },
    { key: 'avg_resolution_tat_hours', header: 'Avg Resol TAT (h)' },
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

  const digestCols: Column<DigestRow>[] = [
    { key: 'category', header: 'Category' },
    { key: 'complaints', header: 'Complaints' },
    { key: 'sla_breached', header: 'SLA Breached' },
    { key: 'avg_response_tat_hours', header: 'Avg Resp TAT (h)' },
    { key: 'avg_resolution_tat_hours', header: 'Avg Resol TAT (h)' },
    { key: 'max_resolution_tat_hours', header: 'Max Resol TAT (h)' },
    { key: 'breach_pct', header: 'Breach %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'complaint_code', header: 'Complaint' },
    { key: 'device_model', header: 'Device' },
    { key: 'severity', header: 'Severity' },
    { key: 'category', header: 'Category' },
    { key: 'triage_status', header: 'Status' },
    { key: 'response_tat_hours', header: 'Resp TAT (h)' },
    { key: 'resolution_tat_hours', header: 'Resol TAT (h)' },
    { key: 'sla_breached', header: 'SLA Breached' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Customer-Complaint Severity-Triage / Response-TAT Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field-engineer customer-complaint log — severity (critical-safety, major, moderate, minor,
        cosmetic) &times; category (device malfunction, service delay, part quality, billing, staff
        conduct, documentation) &times; triage status &times; response TAT &times; resolution TAT
        &times; SLA breach &amp; CAPA closure. Founder-gated view: triage-status distribution,
        severity scorecard, severity &times; category matrix, monthly trend, root-cause pareto, and a
        high-risk queue for critical-safety, SLA-breached &amp; aging-open complaints.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Triage status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No complaints logged yet."
          rowKey={(r, i) => String(r.triage_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Severity scorecard</h2>
        <DataTable
          rows={severityRows}
          columns={severityCols}
          emptyMessage="No severity rollups."
          rowKey={(r, i) => String(r.severity ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Severity &times; category matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No complaints by severity."
          rowKey={(r, i) => `${r.severity}-${r.category}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly complaint trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. TAT-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No TAT-impact rollups."
          rowKey={(r, i) => String(r.category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk complaint queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk complaints."
          rowKey={(r, i) => `${r.complaint_code}-${i}`}
        />
      </section>
    </main>
  );
}
