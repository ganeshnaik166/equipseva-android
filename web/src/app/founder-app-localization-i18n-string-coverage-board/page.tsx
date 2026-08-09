import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { coverage_status: string; boards: number; pct: number };
type LangRow = {
  language_name: string;
  surfaces: number;
  strings_total: number;
  strings_translated: number;
  avg_coverage_pct: number;
  avg_machine_pct: number;
  avg_native_review_pct: number;
  stale_total: number;
  critical_untranslated: number;
};
type MatrixRow = {
  surface_class: string;
  coverage_status: string;
  boards: number;
  avg_coverage_pct: number;
  critical_untranslated: number;
};
type TrendRow = {
  period_month: string;
  boards: number;
  avg_coverage_pct: number;
  avg_machine_pct: number;
  stale_total: number;
  critical_untranslated: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_users_impacted_pct: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  avg_users_impacted_pct: number;
  pct: number;
};
type ImpactRow = {
  impact_level: string;
  findings: number;
  open_findings: number;
  avg_users_impacted_pct: number;
};
type RiskRow = {
  language_name: string;
  app_surface: string;
  coverage_code: string;
  period_month: string;
  coverage_pct: number | null;
  coverage_status: string;
  untranslated_critical: number;
  stale_translations: number;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    langRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3709_coverage_status_rollup'),
    supabase.rpc('founder_r3709_language_scorecard'),
    supabase.rpc('founder_r3709_surface_status_matrix'),
    supabase.rpc('founder_r3709_monthly_coverage_trend'),
    supabase.rpc('founder_r3709_capa_status_board'),
    supabase.rpc('founder_r3709_root_cause_pareto'),
    supabase.rpc('founder_r3709_impact_digest'),
    supabase.rpc('founder_r3709_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const langRows: LangRow[] = (langRes.data as LangRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'coverage_status', header: 'Coverage Status' },
    { key: 'boards', header: 'Boards' },
    { key: 'pct', header: 'Share %' },
  ];

  const langCols: Column<LangRow>[] = [
    { key: 'language_name', header: 'Language' },
    { key: 'surfaces', header: 'Surfaces' },
    { key: 'strings_total', header: 'Strings' },
    { key: 'strings_translated', header: 'Translated' },
    { key: 'avg_coverage_pct', header: 'Avg Coverage %' },
    { key: 'avg_machine_pct', header: 'Avg MT %' },
    { key: 'avg_native_review_pct', header: 'Avg Native Review %' },
    { key: 'stale_total', header: 'Stale' },
    { key: 'critical_untranslated', header: 'Critical Untranslated' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'surface_class', header: 'Surface Class' },
    { key: 'coverage_status', header: 'Coverage Status' },
    { key: 'boards', header: 'Boards' },
    { key: 'avg_coverage_pct', header: 'Avg Coverage %' },
    { key: 'critical_untranslated', header: 'Critical Untranslated' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'boards', header: 'Boards' },
    { key: 'avg_coverage_pct', header: 'Avg Coverage %' },
    { key: 'avg_machine_pct', header: 'Avg MT %' },
    { key: 'stale_total', header: 'Stale' },
    { key: 'critical_untranslated', header: 'Critical Untranslated' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_users_impacted_pct', header: 'Avg Users Impacted %' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'avg_users_impacted_pct', header: 'Avg Users Impacted %' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'impact_level', header: 'Impact Level' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'avg_users_impacted_pct', header: 'Avg Users Impacted %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'language_name', header: 'Language' },
    { key: 'app_surface', header: 'Surface' },
    { key: 'coverage_code', header: 'Code' },
    { key: 'period_month', header: 'Month' },
    { key: 'coverage_pct', header: 'Coverage %' },
    { key: 'coverage_status', header: 'Status' },
    { key: 'untranslated_critical', header: 'Critical Untranslated' },
    { key: 'stale_translations', header: 'Stale' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        App Localization / i18n String-Coverage Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        App localization governance — language (Hindi, Tamil, Telugu, Kannada, Marathi, Bengali)
        &times; app surface (onboarding &amp; KYC, job flow, payments, notifications, help &amp;
        support) &times; string coverage % &times; machine-translation share &times; native-review
        % &times; stale translations &times; critical untranslated strings &amp; CAPA closure.
        Founder-gated view: coverage-status rollups, language scorecards, root-cause pareto, and
        impact-level digest across the translation pipeline.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Coverage status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No coverage boards logged yet."
          rowKey={(r, i) => String(r.coverage_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Language coverage scorecard</h2>
        <DataTable
          rows={langRows}
          columns={langCols}
          emptyMessage="No language rollups."
          rowKey={(r, i) => String(r.language_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Surface class &times; coverage status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No boards by surface class."
          rowKey={(r, i) => `${r.surface_class}-${r.coverage_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly coverage trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Impact-level digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No impact-level rollups."
          rowKey={(r, i) => String(r.impact_level ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk coverage queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk coverage rows."
          rowKey={(r, i) => `${r.coverage_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
