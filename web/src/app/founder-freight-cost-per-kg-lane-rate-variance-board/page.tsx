import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  cost_status: string;
  lanes: number;
  total_spend_rupees: number;
  pct: number;
};
type CarrierRow = {
  carrier_name: string;
  lanes: number;
  total_shipments: number;
  total_spend_rupees: number;
  avg_cost_per_kg: number;
  avg_rate_variance_pct: number;
  leakage_lanes: number;
  worsening_lanes: number;
  on_or_under_pct: number;
};
type MatrixRow = {
  mode: string;
  cost_status: string;
  lanes: number;
  avg_cost_per_kg: number;
  avg_rate_variance_pct: number;
};
type TrendRow = {
  period_month: string;
  lanes: number;
  shipments: number;
  total_weight_kg: number;
  total_spend_rupees: number;
  avg_cost_per_kg: number;
  avg_rate_variance_pct: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  total_monthly_leakage_rupees: number;
  avg_monthly_leakage_rupees: number;
  overdue_or_escalated: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_leakage_rupees: number;
  pct: number;
};
type VarianceRow = {
  trend_dir: string;
  lanes: number;
  avg_rate_variance_pct: number;
  max_rate_variance_pct: number;
  total_spend_rupees: number;
  above_contract_lanes: number;
};
type RiskRow = {
  lane_ref: string;
  lane_name: string;
  carrier_name: string;
  mode: string;
  period_month: string;
  cost_per_kg_rupees: number;
  contracted_rate_rupees: number;
  rate_variance_pct: number;
  cost_status: string;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    carrierRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    varianceRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3662_cost_status_rollup'),
    supabase.rpc('founder_r3662_carrier_scorecard'),
    supabase.rpc('founder_r3662_mode_cost_status_matrix'),
    supabase.rpc('founder_r3662_monthly_cost_trend'),
    supabase.rpc('founder_r3662_capa_status_board'),
    supabase.rpc('founder_r3662_root_cause_pareto'),
    supabase.rpc('founder_r3662_rate_variance_digest'),
    supabase.rpc('founder_r3662_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const carrierRows: CarrierRow[] = (carrierRes.data as CarrierRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const varianceRows: VarianceRow[] = (varianceRes.data as VarianceRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'cost_status', header: 'Cost Status' },
    { key: 'lanes', header: 'Lane-Months' },
    { key: 'total_spend_rupees', header: 'Total Spend (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const carrierCols: Column<CarrierRow>[] = [
    { key: 'carrier_name', header: 'Carrier' },
    { key: 'lanes', header: 'Lane-Months' },
    { key: 'total_shipments', header: 'Shipments' },
    { key: 'total_spend_rupees', header: 'Spend (INR)' },
    { key: 'avg_cost_per_kg', header: 'Avg Cost/Kg (INR)' },
    { key: 'avg_rate_variance_pct', header: 'Avg Variance %' },
    { key: 'leakage_lanes', header: 'Leakage / Spot' },
    { key: 'worsening_lanes', header: 'Worsening' },
    { key: 'on_or_under_pct', header: 'On/Under Contract %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'mode', header: 'Mode' },
    { key: 'cost_status', header: 'Cost Status' },
    { key: 'lanes', header: 'Lane-Months' },
    { key: 'avg_cost_per_kg', header: 'Avg Cost/Kg (INR)' },
    { key: 'avg_rate_variance_pct', header: 'Avg Variance %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'lanes', header: 'Lane-Months' },
    { key: 'shipments', header: 'Shipments' },
    { key: 'total_weight_kg', header: 'Weight (Kg)' },
    { key: 'total_spend_rupees', header: 'Spend (INR)' },
    { key: 'avg_cost_per_kg', header: 'Avg Cost/Kg (INR)' },
    { key: 'avg_rate_variance_pct', header: 'Avg Variance %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'total_monthly_leakage_rupees', header: 'Total Leakage (INR/mo)' },
    { key: 'avg_monthly_leakage_rupees', header: 'Avg Leakage (INR/mo)' },
    { key: 'overdue_or_escalated', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_leakage_rupees', header: 'Total Leakage (INR/mo)' },
    { key: 'pct', header: 'Share %' },
  ];

  const varianceCols: Column<VarianceRow>[] = [
    { key: 'trend_dir', header: 'Trend' },
    { key: 'lanes', header: 'Lane-Months' },
    { key: 'avg_rate_variance_pct', header: 'Avg Variance %' },
    { key: 'max_rate_variance_pct', header: 'Max Variance %' },
    { key: 'total_spend_rupees', header: 'Spend (INR)' },
    { key: 'above_contract_lanes', header: 'Above Contract / Spot / Leakage' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'lane_ref', header: 'Lane Ref' },
    { key: 'lane_name', header: 'Lane' },
    { key: 'carrier_name', header: 'Carrier' },
    { key: 'mode', header: 'Mode' },
    { key: 'period_month', header: 'Month' },
    { key: 'cost_per_kg_rupees', header: 'Cost/Kg (INR)' },
    { key: 'contracted_rate_rupees', header: 'Contracted (INR)' },
    { key: 'rate_variance_pct', header: 'Variance %' },
    { key: 'cost_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Freight Cost-per-Kg / Lane-Rate Variance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Monthly freight cost-per-kg vs contracted lane rates — lane &times; carrier &times; mode
        (air, surface express, surface LTL, rail, courier) &times; rate variance % &times; express
        share &times; fuel surcharge &amp; leakage CAPA closure. Founder-gated view: cost-status
        distribution, carrier scorecards, mode &times; status matrix, monthly cost-per-kg trend,
        root-cause pareto, and the high-risk queue of leakage &amp; spot-heavy lanes with variance
        &gt; 10%.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Cost-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No freight cost records yet."
          rowKey={(r, i) => String(r.cost_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Carrier scorecard</h2>
        <DataTable
          rows={carrierRows}
          columns={carrierCols}
          emptyMessage="No carrier rollups."
          rowKey={(r, i) => String(r.carrier_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Mode &times; cost-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No mode rollups."
          rowKey={(r, i) => `${r.mode}-${r.cost_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly cost-per-kg trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Rate-variance digest</h2>
        <DataTable
          rows={varianceRows}
          columns={varianceCols}
          emptyMessage="No variance rollups."
          rowKey={(r, i) => String(r.trend_dir ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk lane queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk lanes."
          rowKey={(r, i) => `${r.lane_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
