import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { hygiene_status: string; points: number; pct: number };
type SiteRow = {
  site_name: string;
  total_points: number;
  compliant: number;
  cleaning_due: number;
  service_due: number;
  tds_high: number;
  test_failed: number;
  total_complaints: number;
  avg_tds_ppm: number;
  compliant_pct: number;
};
type MatrixRow = {
  point_class: string;
  hygiene_status: string;
  points: number;
  avg_tds_ppm: number;
  total_complaints: number;
};
type TrendRow = {
  period_month: string;
  points: number;
  potability_passed: number;
  potability_failed: number;
  avg_tds_ppm: number;
  avg_cleaning_current_pct: number;
  total_complaints: number;
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
type DigestRow = {
  site_name: string;
  points: number;
  avg_tds_ppm: number;
  max_tds_ppm: number;
  tds_over_limit_points: number;
  potability_fail_points: number;
  total_complaints: number;
};
type RiskRow = {
  site_name: string;
  water_point: string;
  point_class: string;
  period_month: string;
  hygiene_status: string;
  trend_dir: string;
  tds_ppm: number | null;
  tds_limit_ppm: number | null;
  potability_test_passed: boolean;
  complaints: number | null;
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
    supabase.rpc('founder_r3690_hygiene_status_rollup'),
    supabase.rpc('founder_r3690_site_scorecard'),
    supabase.rpc('founder_r3690_point_class_status_matrix'),
    supabase.rpc('founder_r3690_monthly_test_trend'),
    supabase.rpc('founder_r3690_capa_status_board'),
    supabase.rpc('founder_r3690_root_cause_pareto'),
    supabase.rpc('founder_r3690_tds_complaint_digest'),
    supabase.rpc('founder_r3690_high_risk_queue'),
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
    { key: 'hygiene_status', header: 'Hygiene Status' },
    { key: 'points', header: 'Water Points' },
    { key: 'pct', header: 'Share %' },
  ];

  const siteCols: Column<SiteRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'total_points', header: 'Points' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'cleaning_due', header: 'Cleaning Due' },
    { key: 'service_due', header: 'Service Due' },
    { key: 'tds_high', header: 'TDS High' },
    { key: 'test_failed', header: 'Test Failed' },
    { key: 'total_complaints', header: 'Complaints' },
    { key: 'avg_tds_ppm', header: 'Avg TDS ppm' },
    { key: 'compliant_pct', header: 'Compliant %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'point_class', header: 'Point Class' },
    { key: 'hygiene_status', header: 'Hygiene Status' },
    { key: 'points', header: 'Points' },
    { key: 'avg_tds_ppm', header: 'Avg TDS ppm' },
    { key: 'total_complaints', header: 'Complaints' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'points', header: 'Points' },
    { key: 'potability_passed', header: 'Potability Pass' },
    { key: 'potability_failed', header: 'Potability Fail' },
    { key: 'avg_tds_ppm', header: 'Avg TDS ppm' },
    { key: 'avg_cleaning_current_pct', header: 'Avg Cleaning Current %' },
    { key: 'total_complaints', header: 'Complaints' },
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

  const digestCols: Column<DigestRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'points', header: 'Points' },
    { key: 'avg_tds_ppm', header: 'Avg TDS ppm' },
    { key: 'max_tds_ppm', header: 'Max TDS ppm' },
    { key: 'tds_over_limit_points', header: 'Over-Limit Points' },
    { key: 'potability_fail_points', header: 'Potability Fails' },
    { key: 'total_complaints', header: 'Complaints' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'water_point', header: 'Water Point' },
    { key: 'point_class', header: 'Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'hygiene_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'tds_ppm', header: 'TDS ppm' },
    { key: 'tds_limit_ppm', header: 'TDS Limit ppm' },
    { key: 'potability_test_passed', header: 'Potability Pass' },
    { key: 'complaints', header: 'Complaints' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Office Drinking-Water / RO / Tank-Hygiene Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Own-premises drinking-water hygiene log — water point (overhead tanks, underground sumps,
        RO units, water coolers, pantry taps) &times; tank-cleaning schedule &times; RO service
        &times; TDS ppm vs limit &times; potability tests &times; complaints &amp; CAPA closure
        across Mumbai HQ, Chennai branch, Delhi warehouse &amp; Bengaluru refurb center.
        Founder-gated view: hygiene-status rollup, site scorecards, root-cause pareto, and the
        high-risk queue of test-failed / TDS-high points.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Hygiene status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No water points logged yet."
          rowKey={(r, i) => String(r.hygiene_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Site hygiene scorecard</h2>
        <DataTable
          rows={siteRows}
          columns={siteCols}
          emptyMessage="No site rollups."
          rowKey={(r, i) => String(r.site_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Point class &times; hygiene status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No points by class."
          rowKey={(r, i) => `${r.point_class}-${r.hygiene_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly potability test trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. TDS &amp; complaint digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No TDS digest rows."
          rowKey={(r, i) => String(r.site_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk water-point queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk water points."
          rowKey={(r, i) => `${r.water_point}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
