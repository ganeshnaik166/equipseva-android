import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type BugReport = {
  id: string;
  engineer_user_id: string | null;
  bug_title: string;
  bug_kind: string;
  screenshot_attached: boolean;
  repro_steps_md: string | null;
  severity: string;
  reported_at: string;
  fixed_at: string | null;
  fix_time_hours: number | null;
  reporter_bonus_rupees: number;
  status: string;
  owner_email: string | null;
  notes: string | null;
};

type QualityScore = {
  id: string;
  engineer_user_id: string | null;
  quarter_label: string;
  reports_count: number;
  useful_count: number;
  useful_pct: number;
  total_bonus_rupees: number;
  top_bug_kind: string | null;
  owner_email: string | null;
  status: string;
  notes: string | null;
};

type TopReporter = {
  owner_email: string;
  reports_count: number;
  useful_count: number;
  total_bonus_rupees: number;
  useful_pct: number;
};

type SeverityRow = {
  severity: string;
  reports_count: number;
  fixed_count: number;
  avg_fix_hours: number;
  total_bonus_rupees: number;
};

type KindRow = {
  bug_kind: string;
  reports_count: number;
  with_screenshot: number;
  fixed_count: number;
  pct_of_total: number;
};

type TrendRow = {
  month_label: string;
  reports_count: number;
  fixed_count: number;
  with_screenshot: number;
  total_bonus_rupees: number;
};

type Summary = {
  total_reports: number;
  fixed_count: number;
  wont_fix_count: number;
  duplicate_count: number;
  with_screenshot_pct: number;
  fixed_pct: number;
  total_bonus_rupees: number;
  avg_fix_hours: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [reportsRes, scoresRes, topRes, sevRes, kindRes, trendRes, summaryRes] = await Promise.all([
    sb.rpc('list_bug_reports_r2514'),
    sb.rpc('list_quality_scores_r2514'),
    sb.rpc('top_reporter_engineers_r2514'),
    sb.rpc('severity_breakdown_r2514'),
    sb.rpc('bug_kind_distribution_r2514'),
    sb.rpc('monthly_report_trend_r2514'),
    sb.rpc('useful_rate_summary_r2514'),
  ]);

  const reports: BugReport[] = (reportsRes.data ?? []) as BugReport[];
  const scores: QualityScore[] = (scoresRes.data ?? []) as QualityScore[];
  const top: TopReporter[] = (topRes.data ?? []) as TopReporter[];
  const sev: SeverityRow[] = (sevRes.data ?? []) as SeverityRow[];
  const kinds: KindRow[] = (kindRes.data ?? []) as KindRow[];
  const trend: TrendRow[] = (trendRes.data ?? []) as TrendRow[];
  const summary: Summary = ((summaryRes.data ?? [])[0] ?? {
    total_reports: 0,
    fixed_count: 0,
    wont_fix_count: 0,
    duplicate_count: 0,
    with_screenshot_pct: 0,
    fixed_pct: 0,
    total_bonus_rupees: 0,
    avg_fix_hours: 0,
  }) as Summary;

  const reportCols: Column<any>[] = [
    { key: 'reported', header: 'Reported', render: (r: any) => new Date(r.reported_at).toLocaleDateString() },
    { key: 'title', header: 'Title', render: (r: any) => r.bug_title },
    { key: 'kind', header: 'Kind', render: (r: any) => r.bug_kind },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity },
    { key: 'shot', header: 'Screenshot', render: (r: any) => (r.screenshot_attached ? 'yes' : 'no') },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'fix_hours', header: 'Fix hrs', render: (r: any) => (r.fix_time_hours != null ? String(r.fix_time_hours) : '—') },
    { key: 'bonus', header: 'Bonus (Rs)', render: (r: any) => (r.reporter_bonus_rupees > 0 ? `Rs ${r.reporter_bonus_rupees}` : '—') },
    { key: 'owner', header: 'Reporter', render: (r: any) => r.owner_email ?? '—' },
  ];

  const scoreCols: Column<any>[] = [
    { key: 'quarter', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'owner', header: 'Engineer', render: (r: any) => r.owner_email ?? '—' },
    { key: 'reports', header: 'Reports', render: (r: any) => String(r.reports_count) },
    { key: 'useful', header: 'Useful', render: (r: any) => String(r.useful_count) },
    { key: 'pct', header: 'Useful %', render: (r: any) => `${r.useful_pct}%` },
    { key: 'bonus', header: 'Bonus (Rs)', render: (r: any) => `Rs ${r.total_bonus_rupees}` },
    { key: 'top_kind', header: 'Top kind', render: (r: any) => r.top_bug_kind ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const topCols: Column<any>[] = [
    { key: 'owner', header: 'Engineer', render: (r: any) => r.owner_email },
    { key: 'reports', header: 'Reports', render: (r: any) => String(r.reports_count) },
    { key: 'useful', header: 'Useful', render: (r: any) => String(r.useful_count) },
    { key: 'pct', header: 'Useful %', render: (r: any) => `${r.useful_pct}%` },
    { key: 'bonus', header: 'Total bonus (Rs)', render: (r: any) => `Rs ${r.total_bonus_rupees}` },
  ];

  const sevCols: Column<any>[] = [
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity },
    { key: 'reports', header: 'Reports', render: (r: any) => String(r.reports_count) },
    { key: 'fixed', header: 'Fixed', render: (r: any) => String(r.fixed_count) },
    { key: 'avg_hours', header: 'Avg fix hrs', render: (r: any) => String(r.avg_fix_hours) },
    { key: 'bonus', header: 'Bonus (Rs)', render: (r: any) => `Rs ${r.total_bonus_rupees}` },
  ];

  const kindCols: Column<any>[] = [
    { key: 'kind', header: 'Bug kind', render: (r: any) => r.bug_kind },
    { key: 'reports', header: 'Reports', render: (r: any) => String(r.reports_count) },
    { key: 'shot', header: 'With screenshot', render: (r: any) => String(r.with_screenshot) },
    { key: 'fixed', header: 'Fixed', render: (r: any) => String(r.fixed_count) },
    { key: 'pct', header: 'Pct of total', render: (r: any) => `${r.pct_of_total}%` },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month', header: 'Month', render: (r: any) => r.month_label },
    { key: 'reports', header: 'Reports', render: (r: any) => String(r.reports_count) },
    { key: 'fixed', header: 'Fixed', render: (r: any) => String(r.fixed_count) },
    { key: 'shot', header: 'With screenshot', render: (r: any) => String(r.with_screenshot) },
    { key: 'bonus', header: 'Bonus (Rs)', render: (r: any) => `Rs ${r.total_bonus_rupees}` },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer App Bug Report Quality</h1>
        <p className="text-sm text-gray-500">r2514 · bug report × screenshot × repro steps × severity × fix time × reporter bonus</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Total reports</div>
          <div className="text-2xl font-semibold">{summary.total_reports}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Fixed</div>
          <div className="text-2xl font-semibold text-green-600">{summary.fixed_count}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Wont fix</div>
          <div className="text-2xl font-semibold text-red-600">{summary.wont_fix_count}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Duplicates</div>
          <div className="text-2xl font-semibold">{summary.duplicate_count}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">With screenshot %</div>
          <div className="text-2xl font-semibold">{summary.with_screenshot_pct}%</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Fixed %</div>
          <div className="text-2xl font-semibold">{summary.fixed_pct}%</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Avg fix hours</div>
          <div className="text-2xl font-semibold">{summary.avg_fix_hours}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Total bonus paid</div>
          <div className="text-2xl font-semibold">Rs {summary.total_bonus_rupees}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All bug reports</h2>
        <DataTable rows={reports} columns={reportCols} emptyMessage="No bug reports yet" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly quality scores</h2>
        <DataTable rows={scores} columns={scoreCols} emptyMessage="No quality scores yet" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top reporters</h2>
        <DataTable rows={top} columns={topCols} emptyMessage="No reporters yet" rowKey={(r: any, i: number) => String(r.owner_email ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Severity breakdown</h2>
        <DataTable rows={sev} columns={sevCols} emptyMessage="No severity rows" rowKey={(r: any, i: number) => String(r.severity ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Bug kind distribution</h2>
        <DataTable rows={kinds} columns={kindCols} emptyMessage="No bug kinds" rowKey={(r: any, i: number) => String(r.bug_kind ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly trend</h2>
        <DataTable rows={trend} columns={trendCols} emptyMessage="No trend data" rowKey={(r: any, i: number) => String(r.month_label ?? i)} />
      </section>
    </main>
  );
}
