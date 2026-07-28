import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { connectivity_status: string; links: number; pct: number };
type ScoreRow = {
  link_type: string;
  total_links: number;
  online: number;
  degraded: number;
  offline: number;
  remote_fix_ready: number;
  avg_uptime_pct: number;
  avg_latency_ms: number;
  total_dropouts: number;
};
type MatrixRow = {
  link_type: string;
  connectivity_status: string;
  links: number;
  avg_uptime_pct: number;
  total_dropouts: number;
};
type TrendRow = {
  month_start: string;
  links: number;
  avg_uptime_pct: number;
  avg_latency_ms: number;
  total_dropouts: number;
  offline_count: number;
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
  service_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  hospital_name: string;
  engineer_name: string;
  device_model: string;
  connection_id: string;
  link_type: string;
  last_seen: string;
  connectivity_status: string;
  uptime_pct: number;
  avg_latency_ms: number;
  dropouts: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    scoreRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3552_connectivity_status_rollup'),
    supabase.rpc('founder_r3552_link_type_scorecard'),
    supabase.rpc('founder_r3552_link_type_status_matrix'),
    supabase.rpc('founder_r3552_monthly_uptime_trend'),
    supabase.rpc('founder_r3552_capa_status_board'),
    supabase.rpc('founder_r3552_root_cause_pareto'),
    supabase.rpc('founder_r3552_downtime_impact_digest'),
    supabase.rpc('founder_r3552_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const scoreRows: ScoreRow[] = (scoreRes.data as ScoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'connectivity_status', header: 'Connectivity Status' },
    { key: 'links', header: 'Links' },
    { key: 'pct', header: 'Share %' },
  ];

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'link_type', header: 'Link Type' },
    { key: 'total_links', header: 'Links' },
    { key: 'online', header: 'Online' },
    { key: 'degraded', header: 'Degraded' },
    { key: 'offline', header: 'Offline / Blocked' },
    { key: 'remote_fix_ready', header: 'Remote-Fix Ready' },
    { key: 'avg_uptime_pct', header: 'Avg Uptime %' },
    { key: 'avg_latency_ms', header: 'Avg Latency ms' },
    { key: 'total_dropouts', header: 'Dropouts' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'link_type', header: 'Link Type' },
    { key: 'connectivity_status', header: 'Status' },
    { key: 'links', header: 'Links' },
    { key: 'avg_uptime_pct', header: 'Avg Uptime %' },
    { key: 'total_dropouts', header: 'Dropouts' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'month_start', header: 'Month' },
    { key: 'links', header: 'Links' },
    { key: 'avg_uptime_pct', header: 'Avg Uptime %' },
    { key: 'avg_latency_ms', header: 'Avg Latency ms' },
    { key: 'total_dropouts', header: 'Dropouts' },
    { key: 'offline_count', header: 'Offline / Blocked' },
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
    { key: 'service_impact', header: 'Service Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'device_model', header: 'Device' },
    { key: 'connection_id', header: 'Connection' },
    { key: 'link_type', header: 'Link Type' },
    { key: 'last_seen', header: 'Last Seen' },
    { key: 'connectivity_status', header: 'Status' },
    { key: 'uptime_pct', header: 'Uptime %' },
    { key: 'avg_latency_ms', header: 'Latency ms' },
    { key: 'dropouts', header: 'Dropouts' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Field-Connectivity / Remote-Access (VPN) Uptime Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field-device connectivity &amp; remote-access uptime log — engineer &times; hospital &times;
        device &times; link type (VPN, cellular gateway, Wi-Fi, ethernet, service modem, cloud agent)
        &times; uptime % &times; session count &times; average latency &times; dropouts &times;
        connectivity status &times; remote-fix readiness &amp; CAPA closure. Founder-gated view:
        status distribution, link-type scorecards, uptime trend, root-cause pareto, and
        downtime-impact digest across the field fleet.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Connectivity status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No connections logged yet."
          rowKey={(r, i) => String(r.connectivity_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Link-type scorecard</h2>
        <DataTable
          rows={scoreRows}
          columns={scoreCols}
          emptyMessage="No link-type rollups."
          rowKey={(r, i) => String(r.link_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Link type &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No links by type."
          rowKey={(r, i) => `${r.link_type}-${r.connectivity_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly uptime trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.month_start ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Downtime-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No downtime-impact rollups."
          rowKey={(r, i) => String(r.service_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk connectivity queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk connections."
          rowKey={(r, i) => `${r.connection_id}-${r.last_seen}-${i}`}
        />
      </section>
    </main>
  );
}
