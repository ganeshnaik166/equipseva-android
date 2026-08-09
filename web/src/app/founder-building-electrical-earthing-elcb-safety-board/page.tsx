import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { electrical_status: string; panels: number; pct: number };
type SiteRow = {
  site_name: string;
  panels: number;
  safe_panels: number;
  test_due_panels: number;
  resistance_issues: number;
  trip_failure_panels: number;
  hazardous_panels: number;
  total_hotspots: number;
  avg_trip_pass_pct: number;
  safe_pct: number;
};
type MatrixRow = {
  install_zone: string;
  electrical_status: string;
  panels: number;
  avg_max_resistance_ohm: number;
  hotspots: number;
};
type TrendRow = {
  period_month: string;
  panels: number;
  pits_tested: number;
  elcb_tested: number;
  avg_trip_pass_pct: number;
  hotspots: number;
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
  install_zone: string;
  panels: number;
  total_hotspots: number;
  over_resistance_limit: number;
  avg_max_resistance_ohm: number;
  avg_load_imbalance_pct: number;
};
type RiskRow = {
  site_name: string;
  panel_zone: string;
  install_zone: string;
  period_month: string;
  electrical_status: string;
  max_earth_resistance_ohm: number | null;
  resistance_limit_ohm: number | null;
  elcb_trip_pass_pct: number | null;
  thermography_hotspots: number | null;
  trend_dir: string | null;
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
    supabase.rpc('founder_r3689_electrical_status_rollup'),
    supabase.rpc('founder_r3689_site_scorecard'),
    supabase.rpc('founder_r3689_zone_status_matrix'),
    supabase.rpc('founder_r3689_monthly_test_trend'),
    supabase.rpc('founder_r3689_capa_status_board'),
    supabase.rpc('founder_r3689_root_cause_pareto'),
    supabase.rpc('founder_r3689_hotspot_resistance_digest'),
    supabase.rpc('founder_r3689_high_risk_queue'),
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
    { key: 'electrical_status', header: 'Status' },
    { key: 'panels', header: 'Panel Zones' },
    { key: 'pct', header: 'Share %' },
  ];

  const siteCols: Column<SiteRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'panels', header: 'Panel Zones' },
    { key: 'safe_panels', header: 'Safe' },
    { key: 'test_due_panels', header: 'Test Due' },
    { key: 'resistance_issues', header: 'Resistance High' },
    { key: 'trip_failure_panels', header: 'Trip Failures' },
    { key: 'hazardous_panels', header: 'Hazardous' },
    { key: 'total_hotspots', header: 'Hotspots' },
    { key: 'avg_trip_pass_pct', header: 'Avg Trip Pass %' },
    { key: 'safe_pct', header: 'Safe %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'install_zone', header: 'Install Zone' },
    { key: 'electrical_status', header: 'Status' },
    { key: 'panels', header: 'Panel Zones' },
    { key: 'avg_max_resistance_ohm', header: 'Avg Max Earth Ohm' },
    { key: 'hotspots', header: 'Hotspots' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'panels', header: 'Panel Zones' },
    { key: 'pits_tested', header: 'Pits Tested' },
    { key: 'elcb_tested', header: 'ELCBs Tested' },
    { key: 'avg_trip_pass_pct', header: 'Avg Trip Pass %' },
    { key: 'hotspots', header: 'Hotspots' },
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
    { key: 'install_zone', header: 'Install Zone' },
    { key: 'panels', header: 'Panel Zones' },
    { key: 'total_hotspots', header: 'Hotspots' },
    { key: 'over_resistance_limit', header: 'Over Earth Limit' },
    { key: 'avg_max_resistance_ohm', header: 'Avg Max Earth Ohm' },
    { key: 'avg_load_imbalance_pct', header: 'Avg Load Imbalance %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'panel_zone', header: 'Panel Zone' },
    { key: 'install_zone', header: 'Zone Type' },
    { key: 'period_month', header: 'Month' },
    { key: 'electrical_status', header: 'Status' },
    { key: 'max_earth_resistance_ohm', header: 'Max Earth Ohm' },
    { key: 'resistance_limit_ohm', header: 'Limit Ohm' },
    { key: 'elcb_trip_pass_pct', header: 'Trip Pass %' },
    { key: 'thermography_hotspots', header: 'Hotspots' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Building Electrical / Earthing / ELCB Safety Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Own-building electrical installation safety across our warehouses and service centers —
        earthing-pit resistance vs limit (ohm) &times; ELCB/RCCB 30 mA trip tests &times; LT-panel
        thermography hotspots &times; phase load imbalance &times; install zone (LT panel, UPS
        circuit, warehouse lighting, office floor, external perimeter) &amp; CAPA closure.
        Founder-gated view: status rollups, site scorecards, zone &times; status matrix, monthly
        test trend, root-cause pareto, and the hazardous / trip-failure queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Electrical status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No electrical safety checks logged yet."
          rowKey={(r, i) => String(r.electrical_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Site safety scorecard</h2>
        <DataTable
          rows={siteRows}
          columns={siteCols}
          emptyMessage="No site rollups."
          rowKey={(r, i) => String(r.site_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Install zone &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No checks by install zone."
          rowKey={(r, i) => `${r.install_zone}-${r.electrical_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly test trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Hotspot &amp; earth-resistance digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No zone digests."
          rowKey={(r, i) => String(r.install_zone ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk panel queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk panel zones."
          rowKey={(r, i) => `${r.panel_zone}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
