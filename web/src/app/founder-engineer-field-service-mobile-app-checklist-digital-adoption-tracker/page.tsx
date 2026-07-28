import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { adoption_status: string; entries: number; pct: number };
type RegionRow = {
  region: string;
  total_entries: number;
  champions: number;
  adopters: number;
  partial: number;
  laggards: number;
  non_users: number;
  avg_adoption_pct: number;
  avg_checklist_pct: number;
};
type MatrixRow = {
  feature: string;
  adoption_status: string;
  entries: number;
  avg_adoption_pct: number;
  avg_checklist_pct: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  avg_adoption_pct: number;
  avg_checklist_pct: number;
  avg_photo_pct: number;
  laggards: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_gain_pct: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_gain_pct: number;
  pct: number;
};
type ImpactRow = {
  adoption_impact: string;
  findings: number;
  open_findings: number;
  total_gain_pct: number;
};
type RiskRow = {
  engineer_name: string;
  region: string;
  period_month: string;
  feature: string;
  adoption_status: string;
  digital_adoption_pct: number | null;
  checklist_completion_pct: number | null;
  photo_capture_pct: number | null;
  offline_sync_lag_hrs: number | null;
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
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3580_adoption_status_rollup'),
    supabase.rpc('founder_r3580_region_scorecard'),
    supabase.rpc('founder_r3580_feature_adoption_matrix'),
    supabase.rpc('founder_r3580_monthly_adoption_trend'),
    supabase.rpc('founder_r3580_capa_status_board'),
    supabase.rpc('founder_r3580_root_cause_pareto'),
    supabase.rpc('founder_r3580_adoption_impact_digest'),
    supabase.rpc('founder_r3580_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const regionRows: RegionRow[] = (regionRes.data as RegionRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'adoption_status', header: 'Adoption Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'pct', header: 'Share %' },
  ];

  const regionCols: Column<RegionRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'total_entries', header: 'Entries' },
    { key: 'champions', header: 'Champions' },
    { key: 'adopters', header: 'Adopters' },
    { key: 'partial', header: 'Partial' },
    { key: 'laggards', header: 'Laggards' },
    { key: 'non_users', header: 'Non-Users' },
    { key: 'avg_adoption_pct', header: 'Avg Adoption %' },
    { key: 'avg_checklist_pct', header: 'Avg Checklist %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'feature', header: 'Feature' },
    { key: 'adoption_status', header: 'Adoption Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'avg_adoption_pct', header: 'Avg Adoption %' },
    { key: 'avg_checklist_pct', header: 'Avg Checklist %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entries', header: 'Entries' },
    { key: 'avg_adoption_pct', header: 'Avg Adoption %' },
    { key: 'avg_checklist_pct', header: 'Avg Checklist %' },
    { key: 'avg_photo_pct', header: 'Avg Photo %' },
    { key: 'laggards', header: 'Laggards / Non-Users' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_gain_pct', header: 'Avg Expected Gain %' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_gain_pct', header: 'Total Expected Gain %' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'adoption_impact', header: 'Adoption Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_gain_pct', header: 'Total Expected Gain %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'region', header: 'Region' },
    { key: 'period_month', header: 'Month' },
    { key: 'feature', header: 'Feature' },
    { key: 'adoption_status', header: 'Status' },
    { key: 'digital_adoption_pct', header: 'Adoption %' },
    { key: 'checklist_completion_pct', header: 'Checklist %' },
    { key: 'photo_capture_pct', header: 'Photo %' },
    { key: 'offline_sync_lag_hrs', header: 'Sync Lag (hrs)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Field-Service Mobile-App Checklist / Digital-Adoption Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Paperless job-execution adoption log — engineer &times; region &times; feature (checklist,
        photo, signature, parts-scan, GPS, knowledge base) &times; digital-adoption % &times;
        checklist completion &times; photo capture &times; offline sync lag &amp; CAPA closure.
        Founder-gated view: adoption-status distribution, region scorecards, feature &times;
        adoption-status matrix, monthly trend, root-cause pareto, and adoption-impact digest across
        SLA &amp; warranty-evidence surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Adoption-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No adoption entries logged yet."
          rowKey={(r, i) => String(r.adoption_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Region adoption scorecard</h2>
        <DataTable
          rows={regionRows}
          columns={regionCols}
          emptyMessage="No region rollups."
          rowKey={(r, i) => String(r.region ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Feature &times; adoption-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No entries by feature."
          rowKey={(r, i) => `${r.feature}-${r.adoption_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly adoption trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Adoption-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No adoption-impact rollups."
          rowKey={(r, i) => String(r.adoption_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk adoption queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk entries."
          rowKey={(r, i) => `${r.engineer_name}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
