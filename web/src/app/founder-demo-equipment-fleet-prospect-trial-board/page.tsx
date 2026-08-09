import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { fleet_status: string; units: number; pct: number };
type ModelRow = {
  equipment_model: string;
  total_units: number;
  deployed_active: number;
  idle_units: number;
  refurb_flagged: number;
  avg_conversion_pct: number;
  avg_utilization_pct: number;
  avg_condition_score: number;
  total_book_value_rupees: number;
};
type MatrixRow = {
  placement_class: string;
  fleet_status: string;
  units: number;
  avg_days_at_prospect: number;
  total_book_value_rupees: number;
};
type TrendRow = {
  period_month: string;
  units: number;
  trials_completed: number;
  trials_converted: number;
  conversion_pct: number;
  avg_utilization_pct: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_value_at_risk_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_value_at_risk_rupees: number;
  pct: number;
};
type IdleRow = {
  demo_unit_code: string;
  equipment_model: string;
  current_location: string;
  days_at_prospect: number;
  utilization_pct: number;
  fleet_status: string;
  book_value_rupees: number;
  notes: string | null;
};
type RiskRow = {
  demo_unit_code: string;
  equipment_model: string;
  current_location: string;
  period_month: string;
  placement_class: string;
  fleet_status: string;
  condition_score: number | null;
  refurb_needed: boolean;
  book_value_rupees: number | null;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    modelRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    idleRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3712_fleet_status_rollup'),
    supabase.rpc('founder_r3712_equipment_model_scorecard'),
    supabase.rpc('founder_r3712_placement_status_matrix'),
    supabase.rpc('founder_r3712_monthly_conversion_trend'),
    supabase.rpc('founder_r3712_capa_status_board'),
    supabase.rpc('founder_r3712_root_cause_pareto'),
    supabase.rpc('founder_r3712_idle_unit_digest'),
    supabase.rpc('founder_r3712_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const modelRows: ModelRow[] = (modelRes.data as ModelRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const idleRows: IdleRow[] = (idleRes.data as IdleRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'fleet_status', header: 'Fleet Status' },
    { key: 'units', header: 'Units' },
    { key: 'pct', header: 'Share %' },
  ];

  const modelCols: Column<ModelRow>[] = [
    { key: 'equipment_model', header: 'Model' },
    { key: 'total_units', header: 'Units' },
    { key: 'deployed_active', header: 'Deployed' },
    { key: 'idle_units', header: 'Idle / Available' },
    { key: 'refurb_flagged', header: 'Refurb Flagged' },
    { key: 'avg_conversion_pct', header: 'Avg Conv %' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
    { key: 'avg_condition_score', header: 'Avg Condition' },
    { key: 'total_book_value_rupees', header: 'Book Value (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'placement_class', header: 'Placement Class' },
    { key: 'fleet_status', header: 'Fleet Status' },
    { key: 'units', header: 'Units' },
    { key: 'avg_days_at_prospect', header: 'Avg Days at Prospect' },
    { key: 'total_book_value_rupees', header: 'Book Value (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'units', header: 'Units' },
    { key: 'trials_completed', header: 'Trials' },
    { key: 'trials_converted', header: 'Converted' },
    { key: 'conversion_pct', header: 'Conversion %' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_value_at_risk_rupees', header: 'Avg Value at Risk (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_value_at_risk_rupees', header: 'Value at Risk (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const idleCols: Column<IdleRow>[] = [
    { key: 'demo_unit_code', header: 'Unit' },
    { key: 'equipment_model', header: 'Model' },
    { key: 'current_location', header: 'Location' },
    { key: 'days_at_prospect', header: 'Days at Prospect' },
    { key: 'utilization_pct', header: 'Util %' },
    { key: 'fleet_status', header: 'Status' },
    { key: 'book_value_rupees', header: 'Book Value (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'demo_unit_code', header: 'Unit' },
    { key: 'equipment_model', header: 'Model' },
    { key: 'current_location', header: 'Location' },
    { key: 'period_month', header: 'Month' },
    { key: 'placement_class', header: 'Placement' },
    { key: 'fleet_status', header: 'Status' },
    { key: 'condition_score', header: 'Condition' },
    { key: 'refurb_needed', header: 'Refurb?' },
    { key: 'book_value_rupees', header: 'Book Value (INR)' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Demo-Equipment Fleet / Prospect-Trial Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Demo-equipment fleet ops — unit &times; model &times; placement class (hospital trial,
        exhibition demo, training unit, showroom, in transit) &times; days at prospect &times;
        trials completed vs converted &times; utilization &times; condition score &times; refurb
        flag &times; book value &amp; CAPA recovery actions. Founder-gated view: fleet-status
        distribution, model scorecards, monthly trial-to-purchase conversion trend, idle-unit
        digest, and write-down / long-idle high-risk queue across Mumbai, Chennai, Delhi &amp;
        Bengaluru placements.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Fleet status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No demo-fleet units logged yet."
          rowKey={(r, i) => String(r.fleet_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Equipment-model scorecard</h2>
        <DataTable
          rows={modelRows}
          columns={modelCols}
          emptyMessage="No model rollups."
          rowKey={(r, i) => String(r.equipment_model ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Placement class &times; fleet status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No placement rollups."
          rowKey={(r, i) => `${r.placement_class}-${r.fleet_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly conversion trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Idle-unit digest</h2>
        <DataTable
          rows={idleRows}
          columns={idleCols}
          emptyMessage="No idle units."
          rowKey={(r, i) => `${r.demo_unit_code}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk fleet queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk units."
          rowKey={(r, i) => `${r.demo_unit_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
