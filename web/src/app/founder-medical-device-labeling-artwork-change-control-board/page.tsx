import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { control_status: string; records: number; pct: number };
type ScoreRow = {
  component_type: string;
  total_records: number;
  current_ok: number;
  in_change: number;
  obsolete_field: number;
  uncontrolled_or_recall: number;
  total_obsolete_units: number;
  reg_approval_pending: number;
  current_pct: number;
};
type MatrixRow = {
  component_type: string;
  control_status: string;
  records: number;
  total_obsolete_units: number;
  open_change_requests: number;
};
type TrendRow = {
  period_month: string;
  records: number;
  open_change_requests: number;
  total_obsolete_units: number;
  worsening: number;
  reg_approval_needed_cnt: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
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
  device_name: string;
  components: number;
  total_obsolete_units: number;
  recall_linked: number;
  uncontrolled: number;
  total_open_changes: number;
};
type RiskRow = {
  device_name: string;
  artwork_code: string;
  label_component: string;
  component_type: string;
  period_month: string;
  control_status: string;
  current_version: string | null;
  approved_version: string | null;
  obsolete_stock_units: number | null;
  trend_dir: string | null;
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
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3650_control_status_rollup'),
    supabase.rpc('founder_r3650_component_type_scorecard'),
    supabase.rpc('founder_r3650_component_status_matrix'),
    supabase.rpc('founder_r3650_monthly_change_trend'),
    supabase.rpc('founder_r3650_capa_status_board'),
    supabase.rpc('founder_r3650_root_cause_pareto'),
    supabase.rpc('founder_r3650_obsolete_stock_digest'),
    supabase.rpc('founder_r3650_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const scoreRows: ScoreRow[] = (scoreRes.data as ScoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'control_status', header: 'Control Status' },
    { key: 'records', header: 'Records' },
    { key: 'pct', header: 'Share %' },
  ];

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'component_type', header: 'Component Type' },
    { key: 'total_records', header: 'Records' },
    { key: 'current_ok', header: 'Current' },
    { key: 'in_change', header: 'In Change' },
    { key: 'obsolete_field', header: 'Obsolete In Field' },
    { key: 'uncontrolled_or_recall', header: 'Uncontrolled / Recall' },
    { key: 'total_obsolete_units', header: 'Obsolete Units' },
    { key: 'reg_approval_pending', header: 'Reg Approval Needed' },
    { key: 'current_pct', header: 'Current %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'component_type', header: 'Component Type' },
    { key: 'control_status', header: 'Control Status' },
    { key: 'records', header: 'Records' },
    { key: 'total_obsolete_units', header: 'Obsolete Units' },
    { key: 'open_change_requests', header: 'Open Changes' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'open_change_requests', header: 'Open Changes' },
    { key: 'total_obsolete_units', header: 'Obsolete Units' },
    { key: 'worsening', header: 'Worsening' },
    { key: 'reg_approval_needed_cnt', header: 'Reg Approval Needed' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
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
    { key: 'device_name', header: 'Device' },
    { key: 'components', header: 'Components' },
    { key: 'total_obsolete_units', header: 'Obsolete Units' },
    { key: 'recall_linked', header: 'Recall Linked' },
    { key: 'uncontrolled', header: 'Uncontrolled' },
    { key: 'total_open_changes', header: 'Open Changes' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'device_name', header: 'Device' },
    { key: 'artwork_code', header: 'Artwork Code' },
    { key: 'label_component', header: 'Component' },
    { key: 'component_type', header: 'Type' },
    { key: 'period_month', header: 'Month' },
    { key: 'control_status', header: 'Control Status' },
    { key: 'current_version', header: 'Current Ver' },
    { key: 'approved_version', header: 'Approved Ver' },
    { key: 'obsolete_stock_units', header: 'Obsolete Units' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Medical-Device Labeling / Artwork Change-Control Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Device labeling &amp; IFU artwork change-control compliance — component type (primary label,
        carton, IFU, e-IFU, UDI label, warning insert) &times; current vs approved version &times;
        versions in field &times; obsolete stock units &times; open change requests &times;
        regulatory approval &amp; CAPA closure. Founder-gated view: control-status rollups,
        component-type scorecards, root-cause pareto, and obsolete-stock digest across CDSCO,
        UDI &amp; AERB labeling surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Control-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No labeling records logged yet."
          rowKey={(r, i) => String(r.control_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Component-type scorecard</h2>
        <DataTable
          rows={scoreRows}
          columns={scoreCols}
          emptyMessage="No component-type rollups."
          rowKey={(r, i) => String(r.component_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Component type &times; control status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No records by component type."
          rowKey={(r, i) => `${r.component_type}-${r.control_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly change trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Obsolete-stock digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No obsolete-stock rollups."
          rowKey={(r, i) => String(r.device_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk artwork queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk artwork records."
          rowKey={(r, i) => `${r.artwork_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
