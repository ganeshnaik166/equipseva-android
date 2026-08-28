import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { infra_status: string; service_months: number; pct: number };
type ServiceRow = {
  service_name: string;
  service_months: number;
  avg_uptime_pct: number | null;
  total_incidents: number;
  avg_cpu_utilization_avg_pct: number | null;
  avg_memory_utilization_avg_pct: number | null;
  avg_capacity_headroom_pct: number | null;
  autoscale_enabled_count: number;
};
type MatrixRow = {
  service_class: string;
  infra_status: string;
  service_months: number;
  avg_capacity_headroom_pct: number | null;
};
type TrendRow = {
  period_month: string;
  service_months: number;
  avg_uptime_pct: number | null;
  total_incidents: number;
  total_unplanned_downtime_minutes: number;
  worsening_services: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string | null;
  occurrences: number;
  pct: number;
};
type DigestRow = {
  service_class: string;
  capacity_risk_services: number;
  avg_capacity_headroom_pct: number | null;
  avg_cpu_utilization_avg_pct: number | null;
  avg_memory_utilization_avg_pct: number | null;
  avg_disk_utilization_pct: number | null;
};
type RiskRow = {
  service_name: string;
  environment: string;
  period_month: string;
  service_class: string;
  infra_status: string;
  uptime_pct: number | null;
  incidents_count: number | null;
  capacity_headroom_pct: number | null;
  autoscale_enabled: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    serviceRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3727_infra_status_rollup'),
    supabase.rpc('founder_r3727_service_name_scorecard'),
    supabase.rpc('founder_r3727_service_class_status_matrix'),
    supabase.rpc('founder_r3727_monthly_uptime_trend'),
    supabase.rpc('founder_r3727_capa_status_board'),
    supabase.rpc('founder_r3727_root_cause_pareto'),
    supabase.rpc('founder_r3727_capacity_risk_digest'),
    supabase.rpc('founder_r3727_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const serviceRows: ServiceRow[] = (serviceRes.data as ServiceRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'infra_status', header: 'Infra Status' },
    { key: 'service_months', header: 'Service-Months' },
    { key: 'pct', header: 'Share %' },
  ];

  const serviceCols: Column<ServiceRow>[] = [
    { key: 'service_name', header: 'Service' },
    { key: 'service_months', header: 'Service-Months' },
    { key: 'avg_uptime_pct', header: 'Avg Uptime %' },
    { key: 'total_incidents', header: 'Total Incidents' },
    { key: 'avg_cpu_utilization_avg_pct', header: 'Avg CPU %' },
    { key: 'avg_memory_utilization_avg_pct', header: 'Avg Memory %' },
    { key: 'avg_capacity_headroom_pct', header: 'Avg Headroom %' },
    { key: 'autoscale_enabled_count', header: 'Autoscale Enabled' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'service_class', header: 'Service Class' },
    { key: 'infra_status', header: 'Infra Status' },
    { key: 'service_months', header: 'Service-Months' },
    { key: 'avg_capacity_headroom_pct', header: 'Avg Headroom %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'service_months', header: 'Service-Months' },
    { key: 'avg_uptime_pct', header: 'Avg Uptime %' },
    { key: 'total_incidents', header: 'Total Incidents' },
    { key: 'total_unplanned_downtime_minutes', header: 'Unplanned Downtime (min)' },
    { key: 'worsening_services', header: 'Worsening' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'overdue_flag', header: 'Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'service_class', header: 'Service Class' },
    { key: 'capacity_risk_services', header: 'Capacity-Risk Services' },
    { key: 'avg_capacity_headroom_pct', header: 'Avg Headroom %' },
    { key: 'avg_cpu_utilization_avg_pct', header: 'Avg CPU %' },
    { key: 'avg_memory_utilization_avg_pct', header: 'Avg Memory %' },
    { key: 'avg_disk_utilization_pct', header: 'Avg Disk %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'service_name', header: 'Service' },
    { key: 'environment', header: 'Environment' },
    { key: 'period_month', header: 'Month' },
    { key: 'service_class', header: 'Service Class' },
    { key: 'infra_status', header: 'Infra Status' },
    { key: 'uptime_pct', header: 'Uptime %' },
    { key: 'incidents_count', header: 'Incidents' },
    { key: 'capacity_headroom_pct', header: 'Headroom %' },
    { key: 'autoscale_enabled', header: 'Autoscale' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Data-Center / Server Infrastructure Uptime &amp; Capacity Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Internal server/hosting infrastructure uptime, capacity headroom, and incident count per
        service &amp; environment &times; period month &mdash; CPU, memory, and disk utilization,
        planned &amp; unplanned downtime, autoscale coverage, and CAPA closure for capacity-risk
        and degraded services. Distinct from any DB slow-query/index-health page, which is
        query-level database performance, not infra-level uptime/capacity. Founder-gated view:
        infra-status distribution, service scorecards, service-class &times; status matrix,
        monthly uptime trend, CAPA closure board, root-cause pareto, a capacity-risk digest, and a
        high-risk queue of degraded &amp; critical-incident services.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Infra-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No infra uptime rows logged yet."
          rowKey={(r, i) => String(r.infra_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Service scorecard</h2>
        <DataTable
          rows={serviceRows}
          columns={serviceCols}
          emptyMessage="No service rollups."
          rowKey={(r, i) => String(r.service_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Service class &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No services by class."
          rowKey={(r, i) => `${r.service_class}-${r.infra_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly uptime trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Capacity-risk digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No capacity-risk, degraded, or critical-incident services."
          rowKey={(r, i) => String(r.service_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk infra queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk services."
          rowKey={(r, i) => `${r.service_name}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
