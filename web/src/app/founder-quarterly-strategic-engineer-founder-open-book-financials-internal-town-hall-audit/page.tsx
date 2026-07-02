import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SessionRow = {
  session_id: string;
  fiscal_quarter: string;
  session_title: string;
  held_on: string | null;
  format: string;
  attendance_rate_pct: number | null;
  open_book_depth: string;
  trust_lift_score: number | null;
  candor_index: number | null;
  audit_grade: string;
  audit_status: string;
};

type QuarterRollupRow = {
  fiscal_quarter: string;
  sessions_held: number;
  avg_attendance_pct: number | null;
  avg_trust_lift: number | null;
  avg_candor_index: number | null;
  total_revenue_disclosed_rupees: number | null;
  avg_runway_months: number | null;
  a_grade_sessions: number;
  flagged_sessions: number;
};

type FindingOpenRow = {
  finding_id: string;
  finding_code: string;
  session_title: string;
  fiscal_quarter: string;
  severity: string;
  finding_category: string;
  finding_summary: string;
  remediation_status: string;
  remediation_due_on: string | null;
  flagged_by_engineer_count: number;
  trust_impact_delta: number | null;
};

type SeverityRow = {
  severity: string;
  finding_count: number;
  open_count: number;
  avg_trust_impact: number | null;
};

type DepthRow = {
  open_book_depth: string;
  sessions_count: number;
  avg_trust_lift: number | null;
  avg_candor: number | null;
  avg_attendance_pct: number | null;
};

type FormatRow = {
  format: string;
  sessions_count: number;
  avg_attendance_pct: number | null;
  avg_trust_lift: number | null;
  flagged_count: number;
};

type CategoryRow = {
  finding_category: string;
  total_findings: number;
  blocker_high_count: number;
  total_flags_by_engineers: number | null;
  avg_trust_impact: number | null;
};

type HealthRow = { metric: string; value: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [sessions, rollup, openFindings, severity, depth, format, category, health] = await Promise.all([
    supabase.rpc('founder_r3077_townhall_sessions_list'),
    supabase.rpc('founder_r3077_quarter_rollup'),
    supabase.rpc('founder_r3077_findings_open'),
    supabase.rpc('founder_r3077_severity_mix'),
    supabase.rpc('founder_r3077_open_book_depth_breakdown'),
    supabase.rpc('founder_r3077_format_impact'),
    supabase.rpc('founder_r3077_category_findings'),
    supabase.rpc('founder_r3077_program_health'),
  ]);

  const sessionRows: SessionRow[] = (sessions.data as SessionRow[]) || [];
  const rollupRows: QuarterRollupRow[] = (rollup.data as QuarterRollupRow[]) || [];
  const openFindingRows: FindingOpenRow[] = (openFindings.data as FindingOpenRow[]) || [];
  const severityRows: SeverityRow[] = (severity.data as SeverityRow[]) || [];
  const depthRows: DepthRow[] = (depth.data as DepthRow[]) || [];
  const formatRows: FormatRow[] = (format.data as FormatRow[]) || [];
  const categoryRows: CategoryRow[] = (category.data as CategoryRow[]) || [];
  const healthRows: HealthRow[] = (health.data as HealthRow[]) || [];

  const sessionCols: Column<SessionRow>[] = [
    { header: 'Quarter', accessor: (r) => r.fiscal_quarter },
    { header: 'Session', accessor: (r) => r.session_title },
    { header: 'Held', accessor: (r) => (r.held_on ? new Date(r.held_on).toLocaleDateString() : '-') },
    { header: 'Format', accessor: (r) => r.format },
    { header: 'Attend %', accessor: (r) => (r.attendance_rate_pct ?? '-') },
    { header: 'Depth', accessor: (r) => r.open_book_depth },
    { header: 'Trust', accessor: (r) => (r.trust_lift_score ?? '-') },
    { header: 'Candor', accessor: (r) => (r.candor_index ?? '-') },
    { header: 'Grade', accessor: (r) => r.audit_grade },
    { header: 'Status', accessor: (r) => r.audit_status },
  ];

  const rollupCols: Column<QuarterRollupRow>[] = [
    { header: 'Quarter', accessor: (r) => r.fiscal_quarter },
    { header: 'Sessions', accessor: (r) => r.sessions_held },
    { header: 'Avg Attend %', accessor: (r) => (r.avg_attendance_pct ?? '-') },
    { header: 'Avg Trust', accessor: (r) => (r.avg_trust_lift ?? '-') },
    { header: 'Avg Candor', accessor: (r) => (r.avg_candor_index ?? '-') },
    { header: 'Revenue ₹', accessor: (r) => (r.total_revenue_disclosed_rupees ?? 0) },
    { header: 'Runway mo', accessor: (r) => (r.avg_runway_months ?? '-') },
    { header: 'A-grade', accessor: (r) => r.a_grade_sessions },
    { header: 'Flagged', accessor: (r) => r.flagged_sessions },
  ];

  const findingCols: Column<FindingOpenRow>[] = [
    { header: 'Code', accessor: (r) => r.finding_code },
    { header: 'Quarter', accessor: (r) => r.fiscal_quarter },
    { header: 'Session', accessor: (r) => r.session_title },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Category', accessor: (r) => r.finding_category },
    { header: 'Summary', accessor: (r) => r.finding_summary },
    { header: 'Status', accessor: (r) => r.remediation_status },
    { header: 'Due', accessor: (r) => r.remediation_due_on ?? '-' },
    { header: 'Flagged-by-eng', accessor: (r) => r.flagged_by_engineer_count },
    { header: 'Trust Δ', accessor: (r) => (r.trust_impact_delta ?? '-') },
  ];

  const severityCols: Column<SeverityRow>[] = [
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Total', accessor: (r) => r.finding_count },
    { header: 'Open', accessor: (r) => r.open_count },
    { header: 'Avg Trust Δ', accessor: (r) => (r.avg_trust_impact ?? '-') },
  ];

  const depthCols: Column<DepthRow>[] = [
    { header: 'Depth', accessor: (r) => r.open_book_depth },
    { header: 'Sessions', accessor: (r) => r.sessions_count },
    { header: 'Avg Trust', accessor: (r) => (r.avg_trust_lift ?? '-') },
    { header: 'Avg Candor', accessor: (r) => (r.avg_candor ?? '-') },
    { header: 'Avg Attend %', accessor: (r) => (r.avg_attendance_pct ?? '-') },
  ];

  const formatCols: Column<FormatRow>[] = [
    { header: 'Format', accessor: (r) => r.format },
    { header: 'Sessions', accessor: (r) => r.sessions_count },
    { header: 'Avg Attend %', accessor: (r) => (r.avg_attendance_pct ?? '-') },
    { header: 'Avg Trust', accessor: (r) => (r.avg_trust_lift ?? '-') },
    { header: 'Flagged', accessor: (r) => r.flagged_count },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { header: 'Category', accessor: (r) => r.finding_category },
    { header: 'Total', accessor: (r) => r.total_findings },
    { header: 'Blocker+High', accessor: (r) => r.blocker_high_count },
    { header: 'Eng flags', accessor: (r) => (r.total_flags_by_engineers ?? 0) },
    { header: 'Avg Trust Δ', accessor: (r) => (r.avg_trust_impact ?? '-') },
  ];

  const healthCols: Column<HealthRow>[] = [
    { header: 'Metric', accessor: (r) => r.metric },
    { header: 'Value', accessor: (r) => r.value },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 28 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>
          Quarterly Strategic Engineer-Founder Open-Book Financials Internal Town-Hall Audit
        </h1>
        <p style={{ color: '#555', marginTop: 4 }}>
          Round r3077 — audit grade, candor index, open-book depth & remediation tracker.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Program Health</h2>
        <DataTable<HealthRow>
          rows={healthRows}
          columns={healthCols}
          emptyMessage="No health metrics yet"
          rowKey={(r, i) => String(r.metric ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Quarter Rollup</h2>
        <DataTable<QuarterRollupRow>
          rows={rollupRows}
          columns={rollupCols}
          emptyMessage="No quarter rollup yet"
          rowKey={(r, i) => String(r.fiscal_quarter ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>All Town-Hall Sessions</h2>
        <DataTable<SessionRow>
          rows={sessionRows}
          columns={sessionCols}
          emptyMessage="No sessions logged"
          rowKey={(r, i) => String(r.session_id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Open Audit Findings</h2>
        <DataTable<FindingOpenRow>
          rows={openFindingRows}
          columns={findingCols}
          emptyMessage="No open findings — clean audit"
          rowKey={(r, i) => String(r.finding_id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Severity Mix</h2>
        <DataTable<SeverityRow>
          rows={severityRows}
          columns={severityCols}
          emptyMessage="No findings yet"
          rowKey={(r, i) => String(r.severity ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Open-Book Depth Breakdown</h2>
        <DataTable<DepthRow>
          rows={depthRows}
          columns={depthCols}
          emptyMessage="No depth data"
          rowKey={(r, i) => String(r.open_book_depth ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Format Impact</h2>
        <DataTable<FormatRow>
          rows={formatRows}
          columns={formatCols}
          emptyMessage="No format data"
          rowKey={(r, i) => String(r.format ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Findings by Category</h2>
        <DataTable<CategoryRow>
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No category data"
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>
    </main>
  );
}
