import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder engineer competency-test pass-rate — r2302" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  total_tests: number;
  total_engineers_tested: number;
  passed_count: number;
  failed_count: number;
  marginal_count: number;
  overall_pass_rate_pct: number;
  avg_score_pct: number;
  open_training_assignments: number;
  overdue_assignments: number;
  last_90d_tests: number;
};

type TopicRow = {
  topic: string;
  total_tests: number;
  passed: number;
  failed: number;
  marginal: number;
  pass_rate_pct: number;
  avg_score_pct: number;
  open_assignments: number;
};

type RecentTestRow = {
  id: string;
  engineer_id: string;
  engineer_name: string | null;
  topic: string;
  test_cycle: string;
  test_taken_at: string;
  score_pct: number;
  pass_threshold_pct: number;
  result: string;
  attempt_number: number;
  region: string | null;
  certification_eligible: boolean;
};

type LeaderRow = {
  engineer_id: string;
  engineer_name: string | null;
  tests_taken: number;
  passed: number;
  failed: number;
  avg_score_pct: number;
  pass_rate_pct: number;
  last_test_at: string | null;
  open_assignments: number;
};

type OpenAssignmentRow = {
  id: string;
  engineer_id: string;
  topic: string;
  training_module: string;
  reason: string;
  priority: string;
  status: string;
  due_date: string | null;
  days_until_due: number | null;
  is_overdue: boolean;
  assigned_by_email: string | null;
  created_at: string;
};

type GapRow = {
  topic: string;
  total_tests: number;
  pass_rate_pct: number;
  avg_score_pct: number;
  open_assignments: number;
  recommended_action: string;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function resultBadge(r: string): string {
  if (r === "pass") return "text-emerald-700";
  if (r === "fail") return "text-rose-700";
  if (r === "marginal") return "text-amber-700";
  if (r === "retake_required") return "text-orange-700";
  return "text-gray-600";
}

function priorityBadge(p: string): string {
  if (p === "critical") return "text-rose-700 font-semibold";
  if (p === "high") return "text-orange-700";
  if (p === "medium") return "text-amber-700";
  return "text-gray-500";
}

function actionBadge(a: string): string {
  if (a === "urgent_cohort_retraining") return "text-rose-700 font-semibold";
  if (a === "targeted_remedial_module") return "text-amber-700";
  return "text-gray-500";
}

function passRateColor(pct: number): string {
  if (pct >= 85) return "text-emerald-700";
  if (pct >= 70) return "text-amber-700";
  return "text-rose-700";
}

export default async function FounderEngineerCompetencyTestPassRatePage() {
  const sb = await getSupabaseServerClient();
  const [summaryRes, byTopicRes, recentRes, leaderRes, openRes, gapRes] = await Promise.all([
    sb.rpc("r2302_summary_stats"),
    sb.rpc("r2302_pass_rate_by_topic"),
    sb.rpc("r2302_recent_tests", { p_limit: 50 }),
    sb.rpc("r2302_engineer_leaderboard"),
    sb.rpc("r2302_open_training_assignments"),
    sb.rpc("r2302_topic_gap_alerts", { p_min_tests: 3, p_max_pass_rate: 70 }),
  ]);

  if (summaryRes.error) throw new Error(`r2302_summary_stats: ${summaryRes.error.message}`);
  if (byTopicRes.error) throw new Error(`r2302_pass_rate_by_topic: ${byTopicRes.error.message}`);
  if (recentRes.error) throw new Error(`r2302_recent_tests: ${recentRes.error.message}`);
  if (leaderRes.error) throw new Error(`r2302_engineer_leaderboard: ${leaderRes.error.message}`);
  if (openRes.error) throw new Error(`r2302_open_training_assignments: ${openRes.error.message}`);
  if (gapRes.error) throw new Error(`r2302_topic_gap_alerts: ${gapRes.error.message}`);

  const summary = (summaryRes.data?.[0] ?? null) as SummaryRow | null;
  const byTopic = (byTopicRes.data ?? []) as TopicRow[];
  const recent = (recentRes.data ?? []) as RecentTestRow[];
  const leaders = (leaderRes.data ?? []) as LeaderRow[];
  const openAssignments = (openRes.data ?? []) as OpenAssignmentRow[];
  const gaps = (gapRes.data ?? []) as GapRow[];

  const topicColumns: Column<TopicRow>[] = [
    { key: "topic", header: "Topic", render: (r: any) => <span className="font-medium">{r.topic}</span> },
    { key: "total_tests", header: "Tests", render: (r: any) => String(r.total_tests) },
    { key: "passed", header: "Pass", render: (r: any) => <span className="text-emerald-700">{String(r.passed)}</span> },
    { key: "failed", header: "Fail", render: (r: any) => <span className="text-rose-700">{String(r.failed)}</span> },
    { key: "marginal", header: "Marginal", render: (r: any) => <span className="text-amber-700">{String(r.marginal)}</span> },
    { key: "pass_rate_pct", header: "Pass rate %", render: (r: any) => <span className={passRateColor(Number(r.pass_rate_pct))}>{String(r.pass_rate_pct)}</span> },
    { key: "avg_score_pct", header: "Avg score %", render: (r: any) => String(r.avg_score_pct) },
    { key: "open_assignments", header: "Open training", render: (r: any) => String(r.open_assignments) },
  ];

  const recentColumns: Column<RecentTestRow>[] = [
    { key: "test_taken_at", header: "Taken", render: (r: any) => fmtDate(r.test_taken_at) },
    { key: "engineer_name", header: "Engineer", render: (r: any) => r.engineer_name ?? r.engineer_id.slice(0, 8) },
    { key: "topic", header: "Topic", render: (r: any) => r.topic },
    { key: "test_cycle", header: "Cycle", render: (r: any) => r.test_cycle },
    { key: "score_pct", header: "Score %", render: (r: any) => <span className={passRateColor(Number(r.score_pct))}>{String(r.score_pct)}</span> },
    { key: "pass_threshold_pct", header: "Threshold", render: (r: any) => String(r.pass_threshold_pct) },
    { key: "result", header: "Result", render: (r: any) => <span className={resultBadge(r.result)}>{r.result}</span> },
    { key: "attempt_number", header: "Attempt", render: (r: any) => String(r.attempt_number) },
    { key: "region", header: "Region", render: (r: any) => r.region ?? "—" },
    { key: "certification_eligible", header: "Cert eligible", render: (r: any) => (r.certification_eligible ? "yes" : "no") },
  ];

  const leaderColumns: Column<LeaderRow>[] = [
    { key: "engineer_name", header: "Engineer", render: (r: any) => <span className="font-medium">{r.engineer_name ?? r.engineer_id.slice(0, 8)}</span> },
    { key: "tests_taken", header: "Tests", render: (r: any) => String(r.tests_taken) },
    { key: "passed", header: "Pass", render: (r: any) => <span className="text-emerald-700">{String(r.passed)}</span> },
    { key: "failed", header: "Fail", render: (r: any) => <span className="text-rose-700">{String(r.failed)}</span> },
    { key: "avg_score_pct", header: "Avg score %", render: (r: any) => String(r.avg_score_pct) },
    { key: "pass_rate_pct", header: "Pass rate %", render: (r: any) => <span className={passRateColor(Number(r.pass_rate_pct))}>{String(r.pass_rate_pct)}</span> },
    { key: "last_test_at", header: "Last test", render: (r: any) => fmtDate(r.last_test_at) },
    { key: "open_assignments", header: "Open training", render: (r: any) => String(r.open_assignments) },
  ];

  const openColumns: Column<OpenAssignmentRow>[] = [
    { key: "priority", header: "Priority", render: (r: any) => <span className={priorityBadge(r.priority)}>{r.priority}</span> },
    { key: "topic", header: "Topic", render: (r: any) => <span className="font-medium">{r.topic}</span> },
    { key: "training_module", header: "Module", render: (r: any) => r.training_module },
    { key: "reason", header: "Reason", render: (r: any) => r.reason },
    { key: "status", header: "Status", render: (r: any) => r.status },
    { key: "due_date", header: "Due", render: (r: any) => fmtDate(r.due_date) },
    { key: "days_until_due", header: "Days left", render: (r: any) => (r.days_until_due === null ? "—" : <span className={r.is_overdue ? "text-rose-700 font-semibold" : ""}>{String(r.days_until_due)}</span>) },
    { key: "is_overdue", header: "Overdue", render: (r: any) => (r.is_overdue ? <span className="text-rose-700 font-semibold">yes</span> : "no") },
    { key: "assigned_by_email", header: "Assigned by", render: (r: any) => r.assigned_by_email ?? "—" },
    { key: "created_at", header: "Created", render: (r: any) => fmtDate(r.created_at) },
  ];

  const gapColumns: Column<GapRow>[] = [
    { key: "topic", header: "Topic", render: (r: any) => <span className="font-medium">{r.topic}</span> },
    { key: "total_tests", header: "Tests", render: (r: any) => String(r.total_tests) },
    { key: "pass_rate_pct", header: "Pass rate %", render: (r: any) => <span className={passRateColor(Number(r.pass_rate_pct))}>{String(r.pass_rate_pct)}</span> },
    { key: "avg_score_pct", header: "Avg score %", render: (r: any) => String(r.avg_score_pct) },
    { key: "open_assignments", header: "Open training", render: (r: any) => String(r.open_assignments) },
    { key: "recommended_action", header: "Recommended action", render: (r: any) => <span className={actionBadge(r.recommended_action)}>{r.recommended_action}</span> },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Founder engineer competency-test pass-rate — r2302</h1>
        <p className="mt-1 text-xs text-gray-500">
          Periodic competency tests by topic. Pass rate & weak-area gaps surface where the field force needs
          remedial training; assign training modules per engineer to close the gap.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-5">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total tests</div>
          <div className="mt-1 text-lg font-semibold">{summary?.total_tests ?? 0}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Engineers tested</div>
          <div className="mt-1 text-lg font-semibold">{summary?.total_engineers_tested ?? 0}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Pass rate %</div>
          <div className={`mt-1 text-lg font-semibold ${passRateColor(Number(summary?.overall_pass_rate_pct ?? 0))}`}>
            {summary?.overall_pass_rate_pct ?? 0}
          </div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Avg score %</div>
          <div className="mt-1 text-lg font-semibold">{summary?.avg_score_pct ?? 0}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Last 90d tests</div>
          <div className="mt-1 text-lg font-semibold">{summary?.last_90d_tests ?? 0}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Passed</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{summary?.passed_count ?? 0}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Failed</div>
          <div className="mt-1 text-lg font-semibold text-rose-700">{summary?.failed_count ?? 0}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Marginal</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{summary?.marginal_count ?? 0}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Open training</div>
          <div className="mt-1 text-lg font-semibold">{summary?.open_training_assignments ?? 0}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Overdue</div>
          <div className="mt-1 text-lg font-semibold text-rose-700">{summary?.overdue_assignments ?? 0}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Topic gap alerts</h2>
        <p className="text-xs text-gray-500">
          Topics with pass rate &lt;= 70% and &gt;= 3 tests. Urgent (pass &lt; 50%) =&gt; cohort retraining.
        </p>
        <DataTable
          rows={gaps}
          columns={gapColumns}
          rowKey={(r: any, i: number) => String(r.topic ?? i)}
          emptyMessage="No topic gaps above threshold."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Pass rate by topic</h2>
        <p className="text-xs text-gray-500">
          Per-topic breakdown across all cycles. Sorted by lowest pass rate first =&gt; weakest topics surface on top.
        </p>
        <DataTable
          rows={byTopic}
          columns={topicColumns}
          rowKey={(r: any, i: number) => String(r.topic ?? i)}
          emptyMessage="No tests logged yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Engineer leaderboard</h2>
        <p className="text-xs text-gray-500">
          Per-engineer pass rate &amp; open training load. Sorted lowest pass rate first =&gt; remediation candidates.
        </p>
        <DataTable
          rows={leaders}
          columns={leaderColumns}
          rowKey={(r: any, i: number) => String(r.engineer_id ?? i)}
          emptyMessage="No engineer tests yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Open training assignments</h2>
        <p className="text-xs text-gray-500">
          Sorted by priority &amp; due date. Overdue rows highlighted =&gt; chase via field-ops lead.
        </p>
        <DataTable
          rows={openAssignments}
          columns={openColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No open training assignments."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Recent tests</h2>
        <p className="text-xs text-gray-500">Last 50 competency-test attempts across the field force.</p>
        <DataTable
          rows={recent}
          columns={recentColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No recent tests."
        />
      </section>
    </div>
  );
}
