import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { reliability_status: string; models: number; pct: number };
type CatRow = {
  device_category: string;
  models: number;
  total_installed: number;
  total_failures: number;
  avg_mtbf_hours: number;
  avg_availability_pct: number;
  below_target: number;
  poor_models: number;
};
type MatrixRow = {
  device_category: string;
  dominant_failure_mode: string;
  models: number;
  total_failures: number;
  avg_failure_rate_per_1000h: number;
};
type TrendRow = {
  period_month: string;
  models: number;
  avg_mtbf_hours: number;
  avg_availability_pct: number;
  total_failures: number;
  worsening_models: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_cost_rupees: number;
  overdue_escalated: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type ImpactRow = {
  finding_category: string;
  actions: number;
  open_actions: number;
  total_availability_impact_pct: number;
  total_cost_rupees: number;
};
type RiskRow = {
  device_model: string;
  model_code: string;
  device_category: string;
  reliability_status: string;
  mtbf_hours: number;
  target_mtbf_hours: number;
  availability_pct: number | null;
  dominant_failure_mode: string;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    catRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3488_reliability_status_rollup'),
    supabase.rpc('founder_r3488_category_scorecard'),
    supabase.rpc('founder_r3488_category_failure_mode_matrix'),
    supabase.rpc('founder_r3488_monthly_mtbf_trend'),
    supabase.rpc('founder_r3488_capa_status_board'),
    supabase.rpc('founder_r3488_root_cause_pareto'),
    supabase.rpc('founder_r3488_availability_impact_digest'),
    supabase.rpc('founder_r3488_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const catRows: CatRow[] = (catRes.data as CatRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'reliability_status', header: 'Reliability Status' },
    { key: 'models', header: 'Models' },
    { key: 'pct', header: 'Share %' },
  ];

  const catCols: Column<CatRow>[] = [
    { key: 'device_category', header: 'Category' },
    { key: 'models', header: 'Models' },
    { key: 'total_installed', header: 'Installed Units' },
    { key: 'total_failures', header: 'Failures' },
    { key: 'avg_mtbf_hours', header: 'Avg MTBF (h)' },
    { key: 'avg_availability_pct', header: 'Avg Availability %' },
    { key: 'below_target', header: 'Below Target' },
    { key: 'poor_models', header: 'Poor' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'device_category', header: 'Category' },
    { key: 'dominant_failure_mode', header: 'Failure Mode' },
    { key: 'models', header: 'Models' },
    { key: 'total_failures', header: 'Failures' },
    { key: 'avg_failure_rate_per_1000h', header: 'Avg Rate /1000h' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'models', header: 'Models' },
    { key: 'avg_mtbf_hours', header: 'Avg MTBF (h)' },
    { key: 'avg_availability_pct', header: 'Avg Availability %' },
    { key: 'total_failures', header: 'Failures' },
    { key: 'worsening_models', header: 'Worsening' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_escalated', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'finding_category', header: 'Finding Category' },
    { key: 'actions', header: 'Actions' },
    { key: 'open_actions', header: 'Open' },
    { key: 'total_availability_impact_pct', header: 'Availability Impact %' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'device_model', header: 'Device Model' },
    { key: 'model_code', header: 'Code' },
    { key: 'device_category', header: 'Category' },
    { key: 'reliability_status', header: 'Status' },
    { key: 'mtbf_hours', header: 'MTBF (h)' },
    { key: 'target_mtbf_hours', header: 'Target MTBF (h)' },
    { key: 'availability_pct', header: 'Availability %' },
    { key: 'dominant_failure_mode', header: 'Failure Mode' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer MTBF / Equipment-Reliability Failure-Rate Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Per device-model reliability tracker (distinct from MTTR repair-time) &mdash; installed units
        &times; operating hours &times; failures &times; MTBF hours vs target &times; failure-rate per
        1000h &times; availability % &times; reliability status (excellent &rarr; poor) &times;
        dominant failure mode (electronic, mechanical, wear, software, power, sensor, user-induced)
        &times; monthly trend &amp; CAPA closure. Founder-gated view: status distribution, category
        scorecards, failure-mode matrix, root-cause pareto, and availability-impact digest across the
        fleet.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Reliability-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No reliability records yet."
          rowKey={(r, i) => String(r.reliability_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Device-category scorecard</h2>
        <DataTable
          rows={catRows}
          columns={catCols}
          emptyMessage="No category rollups."
          rowKey={(r, i) => String(r.device_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Category &times; failure-mode matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No failure-mode data."
          rowKey={(r, i) => `${r.device_category}-${r.dominant_failure_mode}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly MTBF &amp; availability trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Availability-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No availability-impact rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk reliability queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk models."
          rowKey={(r, i) => `${r.model_code}-${i}`}
        />
      </section>
    </main>
  );
}
