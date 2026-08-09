import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { a11y_status: string; surfaces: number; pct: number };
type PlatformRow = {
  platform: string;
  total_surfaces: number;
  compliant: number;
  minor: number;
  major: number;
  critical: number;
  unaudited: number;
  avg_talkback_pct: number;
  avg_contrast_pct: number;
  compliant_pct: number;
};
type MatrixRow = {
  surface_class: string;
  a11y_status: string;
  surfaces: number;
  avg_audit_pct: number;
  total_critical_issues: number;
};
type TrendRow = {
  period_month: string;
  surfaces: number;
  total_critical_issues: number;
  total_issues_fixed: number;
  avg_audit_pct: number;
  avg_talkback_pct: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_affected_users_pct: number;
  overdue_or_escalated: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  avg_affected_users_pct: number;
  pct: number;
};
type DigestRow = {
  issue_category: string;
  actions: number;
  open_actions: number;
  avg_affected_users_pct: number;
};
type RiskRow = {
  app_surface: string;
  audit_code: string;
  platform: string;
  surface_class: string;
  period_month: string;
  a11y_status: string;
  critical_issues: number;
  issues_fixed: number;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    platformRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3711_a11y_status_rollup'),
    supabase.rpc('founder_r3711_platform_scorecard'),
    supabase.rpc('founder_r3711_surface_class_status_matrix'),
    supabase.rpc('founder_r3711_monthly_issue_trend'),
    supabase.rpc('founder_r3711_capa_status_board'),
    supabase.rpc('founder_r3711_root_cause_pareto'),
    supabase.rpc('founder_r3711_critical_issue_digest'),
    supabase.rpc('founder_r3711_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const platformRows: PlatformRow[] = (platformRes.data as PlatformRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'a11y_status', header: 'A11y Status' },
    { key: 'surfaces', header: 'Surfaces' },
    { key: 'pct', header: 'Share %' },
  ];

  const platformCols: Column<PlatformRow>[] = [
    { key: 'platform', header: 'Platform' },
    { key: 'total_surfaces', header: 'Surfaces' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'minor', header: 'Minor' },
    { key: 'major', header: 'Major' },
    { key: 'critical', header: 'Critical' },
    { key: 'unaudited', header: 'Not Audited' },
    { key: 'avg_talkback_pct', header: 'Avg TalkBack %' },
    { key: 'avg_contrast_pct', header: 'Avg Contrast %' },
    { key: 'compliant_pct', header: 'Compliant %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'surface_class', header: 'Surface Class' },
    { key: 'a11y_status', header: 'A11y Status' },
    { key: 'surfaces', header: 'Surfaces' },
    { key: 'avg_audit_pct', header: 'Avg Audit %' },
    { key: 'total_critical_issues', header: 'Critical Issues' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'surfaces', header: 'Surfaces' },
    { key: 'total_critical_issues', header: 'Critical Issues' },
    { key: 'total_issues_fixed', header: 'Issues Fixed' },
    { key: 'avg_audit_pct', header: 'Avg Audit %' },
    { key: 'avg_talkback_pct', header: 'Avg TalkBack %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_affected_users_pct', header: 'Avg Affected Users %' },
    { key: 'overdue_or_escalated', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'avg_affected_users_pct', header: 'Avg Affected Users %' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'issue_category', header: 'Issue Category' },
    { key: 'actions', header: 'Actions' },
    { key: 'open_actions', header: 'Open' },
    { key: 'avg_affected_users_pct', header: 'Avg Affected Users %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'app_surface', header: 'Surface' },
    { key: 'audit_code', header: 'Audit Code' },
    { key: 'platform', header: 'Platform' },
    { key: 'surface_class', header: 'Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'a11y_status', header: 'Status' },
    { key: 'critical_issues', header: 'Critical' },
    { key: 'issues_fixed', header: 'Fixed' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        App Accessibility (a11y) Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        App accessibility compliance log — surface (onboarding &amp; KYC, job flow, payments,
        notifications, help &amp; support) &times; platform &times; TalkBack / screen-reader label
        coverage &times; contrast pass rate &times; touch-target pass rate &times; font-scaling
        pass rate &times; critical issues &amp; fixes against WCAG targets, with CAPA closure.
        Founder-gated view: a11y status rollups, platform scorecards, surface-class matrices,
        root-cause pareto, and a high-risk queue of critical-blocker &amp; unaudited surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. A11y status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No a11y audits logged yet."
          rowKey={(r, i) => String(r.a11y_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Platform a11y scorecard</h2>
        <DataTable
          rows={platformRows}
          columns={platformCols}
          emptyMessage="No platform rollups."
          rowKey={(r, i) => String(r.platform ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Surface class &times; a11y status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No audits by surface class."
          rowKey={(r, i) => `${r.surface_class}-${r.a11y_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly issue trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Critical-issue digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No issue-category rollups."
          rowKey={(r, i) => String(r.issue_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk surface queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk surfaces."
          rowKey={(r, i) => `${r.audit_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
