import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { close_verdict: string; records: number; pct: number };
type ScoreRow = {
  close_area: string;
  records: number;
  on_time_count: number;
  late_count: number;
  rework_count: number;
  avg_close_day: number;
  total_open_items: number;
  total_data_quality_issues: number;
  on_time_pct: number;
};
type MatrixRow = {
  period_month: string;
  close_area: string;
  planned_close_day: number;
  actual_close_day: number;
  on_time: boolean;
  open_items_count: number;
};
type TrendRow = { period_month: string; areas: number; on_time: number; late: number; avg_mis_lag_days: number };
type CapaRow = { capa_status: string; findings: number; avg_cost_rupees: number; overdue_flag: number };
type CauseRow = { root_cause: string; occurrences: number; total_cost_rupees: number; pct: number };
type ImpactRow = { financial_impact: string; findings: number; open_findings: number; total_cost_rupees: number };
type RiskRow = {
  close_area: string;
  period_month: string;
  owner: string;
  planned_close_day: number;
  actual_close_day: number;
  close_status: string;
  open_items_count: number;
  data_quality_issues: number;
  close_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [verdictRes, scoreRes, matrixRes, trendRes, capaRes, causeRes, impactRes, riskRes] = await Promise.all([
    supabase.rpc('founder_r3397_close_verdict_rollup'),
    supabase.rpc('founder_r3397_area_scorecard'),
    supabase.rpc('founder_r3397_period_area_matrix'),
    supabase.rpc('founder_r3397_period_timeliness_trend'),
    supabase.rpc('founder_r3397_capa_status_board'),
    supabase.rpc('founder_r3397_root_cause_pareto'),
    supabase.rpc('founder_r3397_financial_impact_digest'),
    supabase.rpc('founder_r3397_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const scoreRows: ScoreRow[] = (scoreRes.data as ScoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'close_verdict', header: 'Close Verdict' },
    { key: 'records', header: 'Records' },
    { key: 'pct', header: 'Share %' },
  ];
  const scoreCols: Column<ScoreRow>[] = [
    { key: 'close_area', header: 'Close Area' },
    { key: 'records', header: 'Records' },
    { key: 'on_time_count', header: 'On Time' },
    { key: 'late_count', header: 'Late' },
    { key: 'rework_count', header: 'Rework' },
    { key: 'avg_close_day', header: 'Avg Close WD' },
    { key: 'total_open_items', header: 'Open Items' },
    { key: 'total_data_quality_issues', header: 'DQ Issues' },
    { key: 'on_time_pct', header: 'On-Time %' },
  ];
  const matrixCols: Column<MatrixRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'close_area', header: 'Close Area' },
    { key: 'planned_close_day', header: 'Planned WD' },
    { key: 'actual_close_day', header: 'Actual WD' },
    { key: 'on_time', header: 'On Time' },
    { key: 'open_items_count', header: 'Open Items' },
  ];
  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'areas', header: 'Areas' },
    { key: 'on_time', header: 'On Time' },
    { key: 'late', header: 'Late' },
    { key: 'avg_mis_lag_days', header: 'Avg MIS Lag (d)' },
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
    { key: 'financial_impact', header: 'Financial Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];
  const riskCols: Column<RiskRow>[] = [
    { key: 'close_area', header: 'Close Area' },
    { key: 'period_month', header: 'Period' },
    { key: 'owner', header: 'Owner' },
    { key: 'planned_close_day', header: 'Planned WD' },
    { key: 'actual_close_day', header: 'Actual WD' },
    { key: 'close_status', header: 'Status' },
    { key: 'open_items_count', header: 'Open Items' },
    { key: 'data_quality_issues', header: 'DQ Issues' },
    { key: 'close_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Month-End Financial-Close &amp; MIS-Reporting Timeliness Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Close governance &mdash; close area &times; period &times; planned vs actual close day &times;
        reconciliation &times; open items &times; data quality &times; MIS delivery lag &times; sign-off &amp; CAPA.
        Founder-gated view: close-verdict rollup, area scorecard, period &times; area matrix, and delayed/rework queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Close verdict distribution</h2>
        <DataTable rows={verdictRows} columns={verdictCols} emptyMessage="No close records yet." rowKey={(r, i) => String(r.close_verdict ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Close-area scorecard</h2>
        <DataTable rows={scoreRows} columns={scoreCols} emptyMessage="No area rollups." rowKey={(r, i) => String(r.close_area ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Period &times; area matrix</h2>
        <DataTable rows={matrixRows} columns={matrixCols} emptyMessage="No matrix data." rowKey={(r, i) => `${r.period_month}-${r.close_area}-${i}`} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Period timeliness trend</h2>
        <DataTable rows={trendRows} columns={trendCols} emptyMessage="No trend data." rowKey={(r, i) => String(r.period_month ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable rows={capaRows} columns={capaCols} emptyMessage="No CAPA findings." rowKey={(r, i) => String(r.capa_status ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable rows={causeRows} columns={causeCols} emptyMessage="No root-cause data." rowKey={(r, i) => String(r.root_cause ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Financial-impact digest</h2>
        <DataTable rows={impactRows} columns={impactCols} emptyMessage="No financial-impact rollups." rowKey={(r, i) => String(r.financial_impact ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. Delayed / rework queue</h2>
        <DataTable rows={riskRows} columns={riskCols} emptyMessage="No delayed closes." rowKey={(r, i) => `${r.close_area}-${r.period_month}-${i}`} />
      </section>
    </main>
  );
}
