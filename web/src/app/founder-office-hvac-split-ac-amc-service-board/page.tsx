import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { service_status: string; units: number; pct: number };
type SiteRow = {
  site_name: string;
  total_units: number;
  current_units: number;
  service_due_units: number;
  amc_expiring_units: number;
  breakdown_prone_units: number;
  out_of_service_units: number;
  total_breakdowns: number;
  avg_service_pct: number;
};
type MatrixRow = {
  unit_class: string;
  service_status: string;
  units: number;
  total_breakdowns: number;
  avg_service_pct: number;
};
type TrendRow = {
  period_month: string;
  units: number;
  services_due: number;
  services_done: number;
  avg_service_pct: number;
  gas_topups: number;
  breakdowns: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_cost_rupees: number;
  overdue_or_escalated: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type DigestRow = {
  site_name: string;
  units: number;
  total_breakdowns: number;
  total_gas_topups: number;
  avg_repair_days: number | null;
  worsening_units: number;
};
type RiskRow = {
  unit_code: string;
  site_name: string;
  unit_class: string;
  period_month: string;
  service_status: string;
  trend_dir: string;
  breakdowns: number;
  gas_topups: number;
  avg_repair_days: number | null;
  days_to_amc_expiry: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    siteRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3691_service_status_rollup'),
    supabase.rpc('founder_r3691_site_scorecard'),
    supabase.rpc('founder_r3691_unit_class_status_matrix'),
    supabase.rpc('founder_r3691_monthly_service_trend'),
    supabase.rpc('founder_r3691_capa_status_board'),
    supabase.rpc('founder_r3691_root_cause_pareto'),
    supabase.rpc('founder_r3691_breakdown_digest'),
    supabase.rpc('founder_r3691_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const siteRows: SiteRow[] = (siteRes.data as SiteRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'service_status', header: 'Service Status' },
    { key: 'units', header: 'Units' },
    { key: 'pct', header: 'Share %' },
  ];

  const siteCols: Column<SiteRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'total_units', header: 'Units' },
    { key: 'current_units', header: 'Current' },
    { key: 'service_due_units', header: 'Service Due' },
    { key: 'amc_expiring_units', header: 'AMC Expiring' },
    { key: 'breakdown_prone_units', header: 'Breakdown Prone' },
    { key: 'out_of_service_units', header: 'Out of Service' },
    { key: 'total_breakdowns', header: 'Breakdowns' },
    { key: 'avg_service_pct', header: 'Avg Service %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'unit_class', header: 'Unit Class' },
    { key: 'service_status', header: 'Service Status' },
    { key: 'units', header: 'Units' },
    { key: 'total_breakdowns', header: 'Breakdowns' },
    { key: 'avg_service_pct', header: 'Avg Service %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'units', header: 'Units' },
    { key: 'services_due', header: 'Services Due' },
    { key: 'services_done', header: 'Services Done' },
    { key: 'avg_service_pct', header: 'Avg Service %' },
    { key: 'gas_topups', header: 'Gas Top-ups' },
    { key: 'breakdowns', header: 'Breakdowns' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_or_escalated', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'units', header: 'Units' },
    { key: 'total_breakdowns', header: 'Breakdowns' },
    { key: 'total_gas_topups', header: 'Gas Top-ups' },
    { key: 'avg_repair_days', header: 'Avg Repair Days' },
    { key: 'worsening_units', header: 'Worsening' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'unit_code', header: 'Unit' },
    { key: 'site_name', header: 'Site' },
    { key: 'unit_class', header: 'Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'service_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'breakdowns', header: 'Breakdowns' },
    { key: 'gas_topups', header: 'Gas Top-ups' },
    { key: 'avg_repair_days', header: 'Avg Repair Days' },
    { key: 'days_to_amc_expiry', header: 'Days to AMC Expiry' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Office HVAC / Split-AC AMC &amp; Service Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Own-premises comfort HVAC &amp; split-AC AMC log across Mumbai HQ, Chennai Branch, Delhi
        Warehouse &amp; Bengaluru Refurb Center — unit class (split, cassette, ducted package, VRF
        indoor, window) &times; capacity TR &times; AMC validity &amp; days-to-expiry &times;
        services due vs done &times; gas top-ups &times; breakdowns &times; repair turnaround
        &amp; CAPA closure. Founder-gated view: service-status rollups, site scorecards,
        root-cause pareto, and the out-of-service / breakdown-prone queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Service status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No HVAC units logged yet."
          rowKey={(r, i) => String(r.service_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Site scorecard</h2>
        <DataTable
          rows={siteRows}
          columns={siteCols}
          emptyMessage="No site rollups."
          rowKey={(r, i) => String(r.site_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Unit class &times; service status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No units by class."
          rowKey={(r, i) => `${r.unit_class}-${r.service_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly service trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Breakdown &amp; gas top-up digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No breakdown digest."
          rowKey={(r, i) => String(r.site_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk unit queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk units."
          rowKey={(r, i) => `${r.unit_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
