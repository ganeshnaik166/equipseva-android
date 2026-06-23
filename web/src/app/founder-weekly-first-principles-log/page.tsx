import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type WeekRow = {
  id: string;
  week_start: string;
  week_end: string;
  theme: string;
  status: string;
  questions_logged: number;
  insights_generated: number;
  assumptions_broken: number;
  decisions_changed: number;
  depth_score: number;
  conversion_rate: number;
  reviewed_at: string | null;
  notes: string | null;
};

type EntryRow = {
  id: string;
  logged_at: string;
  week_start: string;
  theme: string;
  question: string;
  domain: string;
  assumption_challenged: string | null;
  insight: string | null;
  led_to_decision: boolean;
  importance: number;
  follow_up_required: boolean;
};

type DomainRow = {
  domain: string;
  question_count: number;
  insight_count: number;
  decision_count: number;
  avg_importance: number;
  share_pct: number;
};

type InsightRow = {
  id: string;
  logged_at: string;
  week_start: string;
  domain: string;
  question: string;
  insight: string | null;
  decision_summary: string | null;
  importance: number;
};

type FollowUpRow = {
  id: string;
  logged_at: string;
  week_start: string;
  domain: string;
  question: string;
  assumption_challenged: string | null;
  age_days: number;
};

type TrendRow = {
  week_start: string;
  theme: string;
  questions_logged: number;
  insights_generated: number;
  depth_score: number;
  rolling_avg_depth: number;
};

type SummaryRow = {
  total_weeks: number;
  total_questions: number;
  total_insights: number;
  total_decisions: number;
  avg_depth: number;
  open_follow_ups: number;
  weeks_reviewed: number;
  insight_conversion_pct: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [weeksRes, entriesRes, domainRes, insightsRes, followRes, trendRes, summaryRes] = await Promise.all([
    supabase.rpc('founder_fp_weeks_list_r2409', { p_limit: 26 }),
    supabase.rpc('founder_fp_entries_recent_r2409', { p_limit: 50 }),
    supabase.rpc('founder_fp_domain_rollup_r2409', { p_weeks: 12 }),
    supabase.rpc('founder_fp_top_insights_r2409', { p_limit: 20 }),
    supabase.rpc('founder_fp_follow_ups_r2409'),
    supabase.rpc('founder_fp_depth_trend_r2409', { p_weeks: 12 }),
    supabase.rpc('founder_fp_summary_r2409'),
  ]);

  const weeks: WeekRow[] = (weeksRes.data as WeekRow[]) ?? [];
  const entries: EntryRow[] = (entriesRes.data as EntryRow[]) ?? [];
  const domains: DomainRow[] = (domainRes.data as DomainRow[]) ?? [];
  const insights: InsightRow[] = (insightsRes.data as InsightRow[]) ?? [];
  const followUps: FollowUpRow[] = (followRes.data as FollowUpRow[]) ?? [];
  const trend: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const summary: SummaryRow | null = ((summaryRes.data as SummaryRow[]) ?? [])[0] ?? null;

  const weekCols: Column<WeekRow>[] = [
    { key: 'week_start', header: 'Week', render: (r: WeekRow) => r.week_start },
    { key: 'theme', header: 'Theme', render: (r: WeekRow) => r.theme },
    { key: 'status', header: 'Status', render: (r: WeekRow) => r.status },
    { key: 'questions_logged', header: 'Qs', render: (r: WeekRow) => r.questions_logged },
    { key: 'insights_generated', header: 'Insights', render: (r: WeekRow) => r.insights_generated },
    { key: 'assumptions_broken', header: 'Assump broke', render: (r: WeekRow) => r.assumptions_broken },
    { key: 'decisions_changed', header: 'Decisions', render: (r: WeekRow) => r.decisions_changed },
    { key: 'depth_score', header: 'Depth /10', render: (r: WeekRow) => r.depth_score },
    { key: 'conversion_rate', header: 'Insight %', render: (r: WeekRow) => `${r.conversion_rate}%` },
    { key: 'reviewed_at', header: 'Reviewed', render: (r: WeekRow) => r.reviewed_at ? r.reviewed_at.slice(0,10) : 'pending' },
  ];

  const entryCols: Column<EntryRow>[] = [
    { key: 'logged_at', header: 'Logged', render: (r: EntryRow) => r.logged_at.slice(0,10) },
    { key: 'week_start', header: 'Week', render: (r: EntryRow) => r.week_start },
    { key: 'domain', header: 'Domain', render: (r: EntryRow) => r.domain },
    { key: 'question', header: 'Question', render: (r: EntryRow) => r.question },
    { key: 'assumption_challenged', header: 'Assumption', render: (r: EntryRow) => r.assumption_challenged ?? '—' },
    { key: 'insight', header: 'Insight', render: (r: EntryRow) => r.insight ?? '—' },
    { key: 'led_to_decision', header: 'Decision?', render: (r: EntryRow) => r.led_to_decision ? 'yes' : 'no' },
    { key: 'importance', header: 'Imp /5', render: (r: EntryRow) => r.importance },
    { key: 'follow_up_required', header: 'Follow-up', render: (r: EntryRow) => r.follow_up_required ? 'open' : '—' },
  ];

  const domainCols: Column<DomainRow>[] = [
    { key: 'domain', header: 'Domain', render: (r: DomainRow) => r.domain },
    { key: 'question_count', header: 'Questions', render: (r: DomainRow) => r.question_count },
    { key: 'insight_count', header: 'Insights', render: (r: DomainRow) => r.insight_count },
    { key: 'decision_count', header: 'Decisions', render: (r: DomainRow) => r.decision_count },
    { key: 'avg_importance', header: 'Avg imp', render: (r: DomainRow) => r.avg_importance },
    { key: 'share_pct', header: 'Share %', render: (r: DomainRow) => `${r.share_pct}%` },
  ];

  const insightCols: Column<InsightRow>[] = [
    { key: 'logged_at', header: 'Logged', render: (r: InsightRow) => r.logged_at.slice(0,10) },
    { key: 'week_start', header: 'Week', render: (r: InsightRow) => r.week_start },
    { key: 'domain', header: 'Domain', render: (r: InsightRow) => r.domain },
    { key: 'question', header: 'Question', render: (r: InsightRow) => r.question },
    { key: 'insight', header: 'Insight', render: (r: InsightRow) => r.insight ?? '—' },
    { key: 'decision_summary', header: 'Decision', render: (r: InsightRow) => r.decision_summary ?? '—' },
    { key: 'importance', header: 'Imp /5', render: (r: InsightRow) => r.importance },
  ];

  const followCols: Column<FollowUpRow>[] = [
    { key: 'logged_at', header: 'Logged', render: (r: FollowUpRow) => r.logged_at.slice(0,10) },
    { key: 'week_start', header: 'Week', render: (r: FollowUpRow) => r.week_start },
    { key: 'domain', header: 'Domain', render: (r: FollowUpRow) => r.domain },
    { key: 'question', header: 'Question', render: (r: FollowUpRow) => r.question },
    { key: 'assumption_challenged', header: 'Assumption', render: (r: FollowUpRow) => r.assumption_challenged ?? '—' },
    { key: 'age_days', header: 'Age (d)', render: (r: FollowUpRow) => r.age_days },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'week_start', header: 'Week', render: (r: TrendRow) => r.week_start },
    { key: 'theme', header: 'Theme', render: (r: TrendRow) => r.theme },
    { key: 'questions_logged', header: 'Qs', render: (r: TrendRow) => r.questions_logged },
    { key: 'insights_generated', header: 'Insights', render: (r: TrendRow) => r.insights_generated },
    { key: 'depth_score', header: 'Depth', render: (r: TrendRow) => r.depth_score },
    { key: 'rolling_avg_depth', header: 'Rolling 4-wk', render: (r: TrendRow) => r.rolling_avg_depth },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Founder weekly first-principles thinking log</h1>
        <p className="text-sm text-gray-600">
          Questions founder asked from first principles each week. Catches assumption drift,
          surfaces insights & decisions, and tracks depth-of-thinking over time.
        </p>
      </header>

      {summary && (
        <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Total weeks</div>
            <div className="text-xl font-semibold">{summary.total_weeks}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Total questions</div>
            <div className="text-xl font-semibold">{summary.total_questions}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Insights</div>
            <div className="text-xl font-semibold">{summary.total_insights}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Decisions changed</div>
            <div className="text-xl font-semibold">{summary.total_decisions}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Avg depth /10</div>
            <div className="text-xl font-semibold">{summary.avg_depth}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Open follow-ups</div>
            <div className="text-xl font-semibold">{summary.open_follow_ups}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Weeks reviewed</div>
            <div className="text-xl font-semibold">{summary.weeks_reviewed}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Insight conv %</div>
            <div className="text-xl font-semibold">{summary.insight_conversion_pct}%</div>
          </div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-medium mb-2">Domain rollup (last 12 weeks)</h2>
        <DataTable rows={domains} emptyMessage="No domain data yet." rowKey={(r: DomainRow) => r.domain} columns={domainCols} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Weekly log (last 26 weeks)</h2>
        <DataTable rows={weeks} emptyMessage="No weeks logged." rowKey={(r: WeekRow) => r.id} columns={weekCols} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Depth trend (rolling 4-week)</h2>
        <DataTable rows={trend} emptyMessage="No trend data." rowKey={(r: TrendRow) => r.week_start} columns={trendCols} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Top insights (importance &gt;= 4)</h2>
        <DataTable rows={insights} emptyMessage="No high-importance insights yet." rowKey={(r: InsightRow) => r.id} columns={insightCols} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Open follow-ups</h2>
        <DataTable rows={followUps} emptyMessage="No open follow-ups." rowKey={(r: FollowUpRow) => r.id} columns={followCols} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recent entries</h2>
        <DataTable rows={entries} emptyMessage="No entries logged." rowKey={(r: EntryRow) => r.id} columns={entryCols} />
      </section>
    </main>
  );
}
