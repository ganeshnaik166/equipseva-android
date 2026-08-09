import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { slo_status: string; entries: number; pct: number };
type AreaRow = {
  service_area: string;
  total_entries: number;
  within_slo: number;
  burning: number;
  exhausted_or_breached: number;
  avg_p95_ms: number;
  avg_error_rate_pct: number;
  avg_budget_remaining_pct: number;
  incidents: number;
};
type MatrixRow = {
  service_class: string;
  slo_status: string;
  entries: number;
  avg_p99_ms: number;
  avg_burn_rate: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  avg_p50_ms: number;
  avg_p95_ms: number;
  avg_p99_ms: number;
  avg_error_rate_pct: number;
  breached: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_budget_impact_pct: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_budget_impact_pct: number;
  pct: number;
};
type BurnRow = {
  burn_band: string;
  entries: number;
  avg_burn_rate: number;
  avg_budget_remaining_pct: number;
  exhausted_or_breached: number;
};
type RiskRow = {
  service_area: string;
  endpoint_group: string;
  period_month: string;
  p95_latency_ms: number;
  p99_latency_ms: number;
  error_rate_pct: number;
  error_budget_remaining_pct: number;
  budget_burn_rate: number;
  slo_status: string;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    areaRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    burnRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3696_slo_status_rollup'),
    supabase.rpc('founder_r3696_service_area_scorecard'),
    supabase.rpc('founder_r3696_class_status_matrix'),
    supabase.rpc('founder_r3696_monthly_latency_trend'),
    supabase.rpc('founder_r3696_capa_status_board'),
    supabase.rpc('founder_r3696_root_cause_pareto'),
    supabase.rpc('founder_r3696_budget_burn_digest'),
    supabase.rpc('founder_r3696_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const areaRows: AreaRow[] = (areaRes.data as AreaRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const burnRows: BurnRow[] = (burnRes.data as BurnRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'slo_status', header: 'SLO Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'pct', header: 'Share %' },
  ];

  const areaCols: Column<AreaRow>[] = [
    { key: 'service_area', header: 'Service Area' },
    { key: 'total_entries', header: 'Entries' },
    { key: 'within_slo', header: 'Within SLO' },
    { key: 'burning', header: 'Burning' },
    { key: 'exhausted_or_breached', header: 'Exhausted / Breached' },
    { key: 'avg_p95_ms', header: 'Avg p95 ms' },
    { key: 'avg_error_rate_pct', header: 'Avg Error %' },
    { key: 'avg_budget_remaining_pct', header: 'Avg Budget Left %' },
    { key: 'incidents', header: 'Incidents' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'service_class', header: 'Service Class' },
    { key: 'slo_status', header: 'SLO Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'avg_p99_ms', header: 'Avg p99 ms' },
    { key: 'avg_burn_rate', header: 'Avg Burn Rate' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entries', header: 'Entries' },
    { key: 'avg_p50_ms', header: 'Avg p50 ms' },
    { key: 'avg_p95_ms', header: 'Avg p95 ms' },
    { key: 'avg_p99_ms', header: 'Avg p99 ms' },
    { key: 'avg_error_rate_pct', header: 'Avg Error %' },
    { key: 'breached', header: 'Exhausted / Breached' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_budget_impact_pct', header: 'Avg Budget Impact %' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_budget_impact_pct', header: 'Total Budget Impact %' },
    { key: 'pct', header: 'Share %' },
  ];

  const burnCols: Column<BurnRow>[] = [
    { key: 'burn_band', header: 'Burn Band' },
    { key: 'entries', header: 'Entries' },
    { key: 'avg_burn_rate', header: 'Avg Burn Rate' },
    { key: 'avg_budget_remaining_pct', header: 'Avg Budget Left %' },
    { key: 'exhausted_or_breached', header: 'Exhausted / Breached' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'service_area', header: 'Service Area' },
    { key: 'endpoint_group', header: 'Endpoint Group' },
    { key: 'period_month', header: 'Month' },
    { key: 'p95_latency_ms', header: 'p95 ms' },
    { key: 'p99_latency_ms', header: 'p99 ms' },
    { key: 'error_rate_pct', header: 'Error %' },
    { key: 'error_budget_remaining_pct', header: 'Budget Left %' },
    { key: 'budget_burn_rate', header: 'Burn Rate' },
    { key: 'slo_status', header: 'SLO Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Platform API Latency / Error-Budget (SLO) Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Platform API/RPC reliability board — service area (auth, marketplace, payments,
        notifications, media) &times; endpoint group &times; monthly latency percentiles
        (p50 / p95 / p99 ms) &times; error rate &times; SLO target &times; error-budget
        remaining &times; burn rate &times; linked incidents &amp; CAPA closure.
        Founder-gated view: SLO status distribution, service-area scorecards, burn-rate
        digest, root-cause pareto, and the high-risk queue of breached or budget-exhausted
        endpoint groups.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. SLO status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No SLO entries logged yet."
          rowKey={(r, i) => String(r.slo_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Service-area reliability scorecard</h2>
        <DataTable
          rows={areaRows}
          columns={areaCols}
          emptyMessage="No service-area rollups."
          rowKey={(r, i) => String(r.service_area ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Service class &times; SLO status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No entries by service class."
          rowKey={(r, i) => `${r.service_class}-${r.slo_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly latency trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Budget-burn digest</h2>
        <DataTable
          rows={burnRows}
          columns={burnCols}
          emptyMessage="No burn-rate rollups."
          rowKey={(r, i) => String(r.burn_band ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk SLO queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk endpoint groups."
          rowKey={(r, i) => `${r.endpoint_group}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
