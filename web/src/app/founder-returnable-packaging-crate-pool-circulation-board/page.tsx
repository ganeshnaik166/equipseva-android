import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { pool_status: string; entries: number; pct: number };
type RegionRow = {
  depot_region: string;
  total_entries: number;
  healthy: number;
  tight_supply: number;
  overdue_returns: number;
  high_loss: number;
  write_off_review: number;
  total_units_issued: number;
  total_units_outstanding: number;
  avg_pool_utilization_pct: number;
};
type MatrixRow = {
  container_class: string;
  pool_status: string;
  entries: number;
  avg_units_outstanding: number;
  avg_pool_utilization_pct: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  total_units_issued: number;
  total_units_returned: number;
  avg_return_cycle_days: number;
  units_damaged_total: number;
  units_lost_total: number;
};
type CapaRow = { capa_status: string; actions: number; past_due: number };
type CauseRow = { root_cause: string; occurrences: number; pct: number };
type DigestRow = {
  depot_region: string;
  overdue_entries: number;
  units_outstanding_total: number;
  avg_return_cycle_days: number;
  deposit_at_risk_rupees: number;
};
type RiskRow = {
  asset_type: string;
  depot_region: string;
  period_month: string;
  container_class: string;
  pool_status: string;
  units_issued: number;
  units_returned: number;
  units_outstanding: number;
  units_damaged: number | null;
  units_lost: number | null;
  avg_return_cycle_days: number | null;
  pool_utilization_pct: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    regionRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3718_pool_status_rollup'),
    supabase.rpc('founder_r3718_depot_region_scorecard'),
    supabase.rpc('founder_r3718_container_class_status_matrix'),
    supabase.rpc('founder_r3718_monthly_cycle_trend'),
    supabase.rpc('founder_r3718_capa_status_board'),
    supabase.rpc('founder_r3718_root_cause_pareto'),
    supabase.rpc('founder_r3718_overdue_returns_digest'),
    supabase.rpc('founder_r3718_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const regionRows: RegionRow[] = (regionRes.data as RegionRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'pool_status', header: 'Pool Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'pct', header: 'Share %' },
  ];

  const regionCols: Column<RegionRow>[] = [
    { key: 'depot_region', header: 'Depot Region' },
    { key: 'total_entries', header: 'Entries' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'tight_supply', header: 'Tight Supply' },
    { key: 'overdue_returns', header: 'Overdue Returns' },
    { key: 'high_loss', header: 'High Loss' },
    { key: 'write_off_review', header: 'Write-Off Review' },
    { key: 'total_units_issued', header: 'Units Issued' },
    { key: 'total_units_outstanding', header: 'Units Outstanding' },
    { key: 'avg_pool_utilization_pct', header: 'Avg Utilization %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'container_class', header: 'Container Class' },
    { key: 'pool_status', header: 'Pool Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'avg_units_outstanding', header: 'Avg Units Outstanding' },
    { key: 'avg_pool_utilization_pct', header: 'Avg Utilization %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_units_issued', header: 'Units Issued' },
    { key: 'total_units_returned', header: 'Units Returned' },
    { key: 'avg_return_cycle_days', header: 'Avg Return Cycle (days)' },
    { key: 'units_damaged_total', header: 'Units Damaged' },
    { key: 'units_lost_total', header: 'Units Lost' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'past_due', header: 'Past Due' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'depot_region', header: 'Depot Region' },
    { key: 'overdue_entries', header: 'Overdue Entries' },
    { key: 'units_outstanding_total', header: 'Units Outstanding' },
    { key: 'avg_return_cycle_days', header: 'Avg Return Cycle (days)' },
    { key: 'deposit_at_risk_rupees', header: 'Deposit at Risk (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'asset_type', header: 'Asset Type' },
    { key: 'depot_region', header: 'Depot Region' },
    { key: 'period_month', header: 'Month' },
    { key: 'container_class', header: 'Container Class' },
    { key: 'pool_status', header: 'Pool Status' },
    { key: 'units_issued', header: 'Issued' },
    { key: 'units_returned', header: 'Returned' },
    { key: 'units_outstanding', header: 'Outstanding' },
    { key: 'units_damaged', header: 'Damaged' },
    { key: 'units_lost', header: 'Lost' },
    { key: 'avg_return_cycle_days', header: 'Avg Return Cycle (days)' },
    { key: 'pool_utilization_pct', header: 'Utilization %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Returnable Packaging / Crate-Pool Circulation Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Returnable packaging (crates, pallets, IBC totes, cylinders) circulating between depots and
        customers — asset type &times; depot region &times; period month &times; units issued vs
        returned &amp; outstanding &times; average return-cycle days &times; deposit collected vs
        refunded &times; damage &amp; loss units &times; replacement cost &times; pool utilization
        &amp; CAPA closure. This tracks the circulating asset pool itself — distinct from
        packaging-spend/dunnage-cost and transit-damage-claims boards. Founder-gated view:
        pool-status distribution, depot-region scorecards, container-class &times; status matrix,
        monthly return-cycle trend, root-cause pareto, an overdue-returns digest, and a high-risk
        queue of overdue / high-loss / write-off-review pool entries.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Pool-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No crate-pool rows logged yet."
          rowKey={(r, i) => String(r.pool_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Depot-region scorecard</h2>
        <DataTable
          rows={regionRows}
          columns={regionCols}
          emptyMessage="No depot-region rollups."
          rowKey={(r, i) => String(r.depot_region ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>
          3. Container class &times; pool status matrix
        </h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No container-class rollups."
          rowKey={(r, i) => `${r.container_class}-${r.pool_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly return-cycle trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Overdue-returns digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No overdue-returns entries."
          rowKey={(r, i) => String(r.depot_region ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk pool queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk pool entries."
          rowKey={(r, i) => `${r.asset_type}-${r.depot_region}-${i}`}
        />
      </section>
    </main>
  );
}
