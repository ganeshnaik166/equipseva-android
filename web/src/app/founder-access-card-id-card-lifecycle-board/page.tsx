import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { lifecycle_status: string; batches: number; pct: number };
type SiteRow = {
  site_name: string;
  total_batches: number;
  cards_active_total: number;
  cards_issued_total: number;
  cards_lost_total: number;
  temp_outstanding_total: number;
  visitor_unreturned_total: number;
  avg_exit_return_pct: number;
  avg_deactivation_sla_pct: number;
  controlled: number;
  at_risk: number;
};
type MatrixRow = {
  card_class: string;
  lifecycle_status: string;
  batches: number;
  cards_lost_total: number;
  avg_deactivation_sla_pct: number;
};
type TrendRow = {
  period_month: string;
  batches: number;
  cards_issued_total: number;
  cards_returned_total: number;
  cards_lost_total: number;
  avg_exit_return_pct: number;
  avg_deactivation_sla_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_exposure_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_exposure_rupees: number;
  pct: number;
};
type ExposureRow = {
  security_impact: string;
  findings: number;
  open_findings: number;
  total_exposure_rupees: number;
};
type RiskRow = {
  card_batch: string;
  site_name: string;
  card_class: string;
  period_month: string;
  lifecycle_status: string;
  cards_lost: number;
  deactivation_sla_pct: number | null;
  temp_cards_outstanding: number;
  visitor_cards_unreturned: number;
  trend_dir: string;
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
    exposureRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3693_lifecycle_status_rollup'),
    supabase.rpc('founder_r3693_site_scorecard'),
    supabase.rpc('founder_r3693_card_class_status_matrix'),
    supabase.rpc('founder_r3693_monthly_issuance_trend'),
    supabase.rpc('founder_r3693_capa_status_board'),
    supabase.rpc('founder_r3693_root_cause_pareto'),
    supabase.rpc('founder_r3693_exposure_digest'),
    supabase.rpc('founder_r3693_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const siteRows: SiteRow[] = (siteRes.data as SiteRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const exposureRows: ExposureRow[] = (exposureRes.data as ExposureRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'lifecycle_status', header: 'Lifecycle Status' },
    { key: 'batches', header: 'Batches' },
    { key: 'pct', header: 'Share %' },
  ];

  const siteCols: Column<SiteRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'total_batches', header: 'Batches' },
    { key: 'cards_active_total', header: 'Active' },
    { key: 'cards_issued_total', header: 'Issued' },
    { key: 'cards_lost_total', header: 'Lost' },
    { key: 'temp_outstanding_total', header: 'Temp Outstanding' },
    { key: 'visitor_unreturned_total', header: 'Visitor Unreturned' },
    { key: 'avg_exit_return_pct', header: 'Avg Exit Return %' },
    { key: 'avg_deactivation_sla_pct', header: 'Avg Deact SLA %' },
    { key: 'controlled', header: 'Controlled' },
    { key: 'at_risk', header: 'At Risk' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'card_class', header: 'Card Class' },
    { key: 'lifecycle_status', header: 'Lifecycle Status' },
    { key: 'batches', header: 'Batches' },
    { key: 'cards_lost_total', header: 'Lost' },
    { key: 'avg_deactivation_sla_pct', header: 'Avg Deact SLA %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'batches', header: 'Batches' },
    { key: 'cards_issued_total', header: 'Issued' },
    { key: 'cards_returned_total', header: 'Returned on Exit' },
    { key: 'cards_lost_total', header: 'Lost' },
    { key: 'avg_exit_return_pct', header: 'Avg Exit Return %' },
    { key: 'avg_deactivation_sla_pct', header: 'Avg Deact SLA %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_exposure_rupees', header: 'Avg Exposure (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_exposure_rupees', header: 'Total Exposure (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const exposureCols: Column<ExposureRow>[] = [
    { key: 'security_impact', header: 'Security Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_exposure_rupees', header: 'Total Exposure (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'card_batch', header: 'Batch' },
    { key: 'site_name', header: 'Site' },
    { key: 'card_class', header: 'Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'lifecycle_status', header: 'Status' },
    { key: 'cards_lost', header: 'Lost' },
    { key: 'deactivation_sla_pct', header: 'Deact SLA %' },
    { key: 'temp_cards_outstanding', header: 'Temp Outstanding' },
    { key: 'visitor_cards_unreturned', header: 'Visitor Unreturned' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Access-Card / ID-Card Lifecycle Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Own-premises access/ID-card lifecycle log — card class (employee, contractor, temp,
        visitor, vehicle tag) &times; site &times; issuance &times; exit-return recovery &times;
        lost-card deactivation SLA &times; temp-card sprawl &times; visitor-card returns &amp; CAPA
        closure across Mumbai HQ, Chennai Branch, Delhi Warehouse &amp; Bengaluru Refurb Center.
        Founder-gated view: lifecycle-status rollups, site scorecards, root-cause pareto, and
        security-exposure digest.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Lifecycle status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No card lifecycle batches logged yet."
          rowKey={(r, i) => String(r.lifecycle_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Site lifecycle scorecard</h2>
        <DataTable
          rows={siteRows}
          columns={siteCols}
          emptyMessage="No site rollups."
          rowKey={(r, i) => String(r.site_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Card class &times; lifecycle status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No batches by card class."
          rowKey={(r, i) => `${r.card_class}-${r.lifecycle_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly issuance trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Security-exposure digest</h2>
        <DataTable
          rows={exposureRows}
          columns={exposureCols}
          emptyMessage="No exposure rollups."
          rowKey={(r, i) => String(r.security_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk lifecycle queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk batches."
          rowKey={(r, i) => `${r.card_batch}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
