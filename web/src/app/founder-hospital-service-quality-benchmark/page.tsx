import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';
import { recomputeQuarterAction, logReviewActionAction } from './actions';

export const dynamic = 'force-dynamic';

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border bg-white p-3 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-lg font-semibold text-gray-900">{value}</div>
    </div>
  );
}

function GradePill({ grade }: { grade: string | null }) {
  const g = grade ?? "-";
  const cls =
    g === 'A' ? 'bg-emerald-100 text-emerald-800' :
    g === 'B' ? 'bg-sky-100 text-sky-800' :
    g === 'C' ? 'bg-amber-100 text-amber-800' :
    g === 'D' ? 'bg-rose-100 text-rose-800' :
                'bg-gray-100 text-gray-700';
  return <span className={`inline-flex rounded px-2 py-0.5 text-xs font-semibold ${cls}`}>{g}</span>;
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [overviewRes, rankingsRes, bottomRes, trendRes, actionsRes] = await Promise.all([
    sb.rpc('founder_hsq_overview'),
    sb.rpc('founder_hsq_latest_rankings'),
    sb.rpc('founder_hsq_bottom_quartile'),
    sb.rpc('founder_hsq_quarterly_trend'),
    sb.rpc('founder_hsq_recent_actions'),
  ]);

  const o: any = (overviewRes.data && overviewRes.data[0]) || {};
  const rankings: any[] = rankingsRes.data || [];
  const bottom: any[] = bottomRes.data || [];
  const trend: any[] = trendRes.data || [];
  const actions: any[] = actionsRes.data || [];

  await sb.rpc('log_founder_hsq_view', { p_view: 'hospital_service_quality_benchmark' });

  const rankCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? "-" },
    { key: 'city', header: 'City', render: (r: any) => r.city ?? "-" },
    { key: 'grade', header: 'Grade', render: (r: any) => <GradePill grade={r.letter_grade} /> },
    { key: 'composite_score', header: 'Score', render: (r: any) => (r.composite_score ?? "-") },
    { key: 'nps_score', header: 'NPS', render: (r: any) => (r.nps_score ?? "-") },
    { key: 'uptime_pct', header: 'Uptime %', render: (r: any) => (r.uptime_pct ?? "-") },
    { key: 'first_response_min', header: 'Resp (min)', render: (r: any) => (r.first_response_min ?? "-") },
    { key: 'recurrence_pct', header: 'Recur %', render: (r: any) => (r.recurrence_pct ?? "-") },
    { key: 'jobs_completed', header: 'Jobs', render: (r: any) => (r.jobs_completed ?? 0) },
    { key: 'flagged_for_review', header: 'Flag', render: (r: any) => r.flagged_for_review ? 'YES' : '-' },
  ];

  const bottomCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? "-" },
    { key: 'city', header: 'City', render: (r: any) => r.city ?? "-" },
    { key: 'grade', header: 'Grade', render: (r: any) => <GradePill grade={r.letter_grade} /> },
    { key: 'composite_score', header: 'Score', render: (r: any) => (r.composite_score ?? "-") },
    { key: 'nps_score', header: 'NPS', render: (r: any) => (r.nps_score ?? "-") },
    { key: 'uptime_pct', header: 'Uptime %', render: (r: any) => (r.uptime_pct ?? "-") },
    { key: 'recurrence_pct', header: 'Recur %', render: (r: any) => (r.recurrence_pct ?? "-") },
    { key: 'jobs_completed', header: 'Jobs', render: (r: any) => (r.jobs_completed ?? 0) },
    {
      key: 'action', header: 'Action', render: (r: any) => (
        <form action={logReviewActionAction} className="flex flex-wrap gap-1">
          <input type="hidden" name="snapshot_id" value={r.id} />
          <select name="action_kind" className="rounded border px-1 py-0.5 text-xs">
            <option value="escalate">escalate</option>
            <option value="outreach">outreach</option>
            <option value="watchlist">watchlist</option>
            <option value="suspend">suspend</option>
            <option value="clear">clear</option>
          </select>
          <input name="notes" placeholder="notes" className="rounded border px-1 py-0.5 text-xs" />
          <button className="rounded bg-gray-900 px-2 py-0.5 text-xs font-medium text-white">Log</button>
        </form>
      ),
    },
  ];

  const trendCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label ?? "-" },
    { key: 'hospitals_graded', header: 'Graded', render: (r: any) => (r.hospitals_graded ?? 0) },
    { key: 'avg_composite', header: 'Avg Score', render: (r: any) => (r.avg_composite ?? "-") },
    { key: 'avg_nps', header: 'Avg NPS', render: (r: any) => (r.avg_nps ?? "-") },
    { key: 'avg_uptime', header: 'Avg Uptime %', render: (r: any) => (r.avg_uptime ?? "-") },
    { key: 'avg_first_response_min', header: 'Avg Resp (min)', render: (r: any) => (r.avg_first_response_min ?? "-") },
    { key: 'avg_recurrence_pct', header: 'Avg Recur %', render: (r: any) => (r.avg_recurrence_pct ?? "-") },
    { key: 'grade_d_count', header: 'Grade D', render: (r: any) => (r.grade_d_count ?? 0) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'created_at', header: 'When', render: (r: any) => new Date(r.created_at).toLocaleString() },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? "-" },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind ?? "-" },
    { key: 'action_notes', header: 'Notes', render: (r: any) => r.action_notes ?? "-" },
    { key: 'actor_email', header: 'By', render: (r: any) => r.actor_email ?? "-" },
  ];

  const topPerformers = rankings.filter((r: any) => r.letter_grade === 'A').slice(0, 10);
  const topCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? "-" },
    { key: 'city', header: 'City', render: (r: any) => r.city ?? "-" },
    { key: 'composite_score', header: 'Score', render: (r: any) => (r.composite_score ?? "-") },
    { key: 'nps_score', header: 'NPS', render: (r: any) => (r.nps_score ?? "-") },
    { key: 'uptime_pct', header: 'Uptime %', render: (r: any) => (r.uptime_pct ?? "-") },
    { key: 'jobs_completed', header: 'Jobs', render: (r: any) => (r.jobs_completed ?? 0) },
  ];

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-4">
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold text-gray-900">Hospital Service-Quality Benchmark</h1>
          <p className="text-sm text-gray-600">
            Quarterly composite score across NPS, uptime, first-response, and recurrence. Rank A through D; bottom quartile surfaces here.
          </p>
        </div>
        <form action={recomputeQuarterAction}>
          <button className="rounded bg-emerald-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-emerald-700">
            Recompute current quarter
          </button>
        </form>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <Kpi label="Latest Quarter" value={o.latest_quarter ?? "-"} />
        <Kpi label="Hospitals Total" value={String(o.total_hospitals ?? 0)} />
        <Kpi label="Hospitals Graded" value={String(o.hospitals_graded ?? 0)} />
        <Kpi label="Flagged for Review" value={String(o.flagged_count ?? 0)} />
        <Kpi label="Grade A" value={String(o.grade_a_count ?? 0)} />
        <Kpi label="Grade B" value={String(o.grade_b_count ?? 0)} />
        <Kpi label="Grade C" value={String(o.grade_c_count ?? 0)} />
        <Kpi label="Grade D" value={String(o.grade_d_count ?? 0)} />
        <Kpi label="Avg Composite" value={String(o.avg_composite_score ?? "-")} />
        <Kpi label="Avg NPS" value={String(o.avg_nps_score ?? "-")} />
        <Kpi label="Avg Uptime %" value={String(o.avg_uptime_pct ?? "-")} />
        <Kpi label="Avg Resp (min)" value={String(o.avg_first_response_min ?? "-")} />
        <Kpi label="Avg Recur %" value={String(o.avg_recurrence_pct ?? "-")} />
        <Kpi label="Bottom Quartile Cases" value={String(bottom.length)} />
        <Kpi label="Recent Actions" value={String(actions.length)} />
        <Kpi label="Quarters Tracked" value={String(trend.length)} />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold text-gray-900">Bottom quartile (Grade D and flagged)</h2>
        <DataTable<any> rows={bottom} columns={bottomCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold text-gray-900">Top performers (Grade A)</h2>
        <DataTable<any> rows={topPerformers} columns={topCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold text-gray-900">Latest-quarter rankings</h2>
        <DataTable<any> rows={rankings} columns={rankCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold text-gray-900">Quarter-over-quarter trend</h2>
        <DataTable<any> rows={trend} columns={trendCols} rowKey={(r: any) => r.quarter_label} />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold text-gray-900">Recent review actions</h2>
        <DataTable<any> rows={actions} columns={actionCols} rowKey={(r: any) => r.id} />
      </section>

      <footer className="pt-4 text-xs text-gray-500">
        Composite = (rating/5)*40 + uptime*30 + responsiveness*20 + recurrence*10. Grades: A {String.fromCharCode(8805)} 80, B {String.fromCharCode(8805)} 65, C {String.fromCharCode(8805)} 50, else D. Total receivables view {formatRupees(0)} placeholder.
      </footer>
    </div>
  );
}