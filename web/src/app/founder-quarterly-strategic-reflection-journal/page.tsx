import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Reflection = {
  reflection_id: string;
  quarter_label: string;
  reflection_date: string;
  topic: string;
  insight: string;
  outcome: string;
  status: string;
  confidence_score: number;
  impact_score: number;
  follow_up_owner: string;
  follow_up_due: string | null;
};

type FollowUp = {
  follow_up_id: string;
  reflection_id: string;
  action_title: string;
  owner: string;
  due_date: string;
  completed_date: string | null;
  state: string;
  effort_hours: number;
  business_lift_score: number;
};

type ByTopic = {
  topic: string;
  reflection_count: number;
  avg_impact: number;
  win_count: number;
};

type Overdue = {
  follow_up_id: string;
  action_title: string;
  owner: string;
  due_date: string;
  days_overdue: number;
  state: string;
  business_lift_score: number;
};

type Quarterly = {
  quarter_label: string;
  reflection_count: number;
  avg_confidence: number;
  avg_impact: number;
  wins: number;
  losses: number;
};

type TopLesson = {
  reflection_id: string;
  quarter_label: string;
  topic: string;
  lessons: string;
  impact_score: number;
  outcome: string;
};

type Kpi = {
  total_reflections: number;
  wins: number;
  open_count: number;
  avg_confidence: number;
  avg_impact: number;
  follow_ups_total: number;
  follow_ups_done: number;
  follow_ups_overdue: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, reflRes, fuRes, topicRes, overdueRes, quarterRes, lessonsRes] = await Promise.all([
    supabase.rpc('founder_r2821_kpi_summary'),
    supabase.rpc('founder_r2821_list_reflections'),
    supabase.rpc('founder_r2821_list_follow_ups'),
    supabase.rpc('founder_r2821_by_topic'),
    supabase.rpc('founder_r2821_overdue_follow_ups'),
    supabase.rpc('founder_r2821_quarterly_rollup'),
    supabase.rpc('founder_r2821_top_lessons'),
  ]);

  const kpi: Kpi | null = (kpiRes.data?.[0] as Kpi) ?? null;
  const reflections: Reflection[] = (reflRes.data as Reflection[]) ?? [];
  const followUps: FollowUp[] = (fuRes.data as FollowUp[]) ?? [];
  const byTopic: ByTopic[] = (topicRes.data as ByTopic[]) ?? [];
  const overdue: Overdue[] = (overdueRes.data as Overdue[]) ?? [];
  const quarterly: Quarterly[] = (quarterRes.data as Quarterly[]) ?? [];
  const topLessons: TopLesson[] = (lessonsRes.data as TopLesson[]) ?? [];

  const kpiCards = [
    { label: 'Total reflections', value: kpi?.total_reflections ?? 0 },
    { label: 'Wins', value: kpi?.wins ?? 0 },
    { label: 'Open', value: kpi?.open_count ?? 0 },
    { label: 'Avg confidence', value: kpi?.avg_confidence ?? 0 },
    { label: 'Avg impact', value: kpi?.avg_impact ?? 0 },
    { label: 'Follow-ups total', value: kpi?.follow_ups_total ?? 0 },
    { label: 'Follow-ups done', value: kpi?.follow_ups_done ?? 0 },
    { label: 'Follow-ups overdue', value: kpi?.follow_ups_overdue ?? 0 },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Quarterly Strategic Reflection Journal</h1>
        <p className="text-sm text-gray-600 mt-1">
          Founder-only log of insight → adjustment → outcome → lessons → follow-up across quarters.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">KPIs</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {kpiCards.map((c) => (
            <div key={c.label} className="border rounded-lg p-4 bg-white">
              <div className="text-xs uppercase tracking-wide text-gray-500">{c.label}</div>
              <div className="text-2xl font-semibold mt-1">{String(c.value)}</div>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Quarterly rollup</h2>
        <DataTable
          rows={quarterly}
          rowKey={(r, i) => String((r as Quarterly).quarter_label ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'quarter_label', header: 'Quarter', render: (r: Quarterly) => r.quarter_label },
            { key: 'reflection_count', header: 'Reflections', render: (r: Quarterly) => String(r.reflection_count) },
            { key: 'avg_confidence', header: 'Avg confidence', render: (r: Quarterly) => String(r.avg_confidence) },
            { key: 'avg_impact', header: 'Avg impact', render: (r: Quarterly) => String(r.avg_impact) },
            { key: 'wins', header: 'Wins', render: (r: Quarterly) => String(r.wins) },
            { key: 'losses', header: 'Losses', render: (r: Quarterly) => String(r.losses) },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">By topic</h2>
        <DataTable
          rows={byTopic}
          rowKey={(r, i) => String((r as ByTopic).topic ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'topic', header: 'Topic', render: (r: ByTopic) => r.topic },
            { key: 'reflection_count', header: 'Count', render: (r: ByTopic) => String(r.reflection_count) },
            { key: 'avg_impact', header: 'Avg impact', render: (r: ByTopic) => String(r.avg_impact) },
            { key: 'win_count', header: 'Wins', render: (r: ByTopic) => String(r.win_count) },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Reflections journal</h2>
        <DataTable
          rows={reflections}
          rowKey={(r, i) => String((r as Reflection).reflection_id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'reflection_id', header: 'ID', render: (r: Reflection) => r.reflection_id },
            { key: 'quarter_label', header: 'Quarter', render: (r: Reflection) => r.quarter_label },
            { key: 'reflection_date', header: 'Date', render: (r: Reflection) => r.reflection_date },
            { key: 'topic', header: 'Topic', render: (r: Reflection) => r.topic },
            { key: 'insight', header: 'Insight', render: (r: Reflection) => r.insight },
            { key: 'outcome', header: 'Outcome', render: (r: Reflection) => r.outcome },
            { key: 'status', header: 'Status', render: (r: Reflection) => r.status },
            { key: 'confidence_score', header: 'Conf', render: (r: Reflection) => String(r.confidence_score) },
            { key: 'impact_score', header: 'Impact', render: (r: Reflection) => String(r.impact_score) },
            { key: 'follow_up_owner', header: 'Owner', render: (r: Reflection) => r.follow_up_owner },
            { key: 'follow_up_due', header: 'Due', render: (r: Reflection) => r.follow_up_due ?? '-' },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Top lessons (by impact)</h2>
        <DataTable
          rows={topLessons}
          rowKey={(r, i) => String((r as TopLesson).reflection_id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'reflection_id', header: 'ID', render: (r: TopLesson) => r.reflection_id },
            { key: 'quarter_label', header: 'Quarter', render: (r: TopLesson) => r.quarter_label },
            { key: 'topic', header: 'Topic', render: (r: TopLesson) => r.topic },
            { key: 'lessons', header: 'Lesson', render: (r: TopLesson) => r.lessons },
            { key: 'impact_score', header: 'Impact', render: (r: TopLesson) => String(r.impact_score) },
            { key: 'outcome', header: 'Outcome', render: (r: TopLesson) => r.outcome },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Follow-ups</h2>
        <DataTable
          rows={followUps}
          rowKey={(r, i) => String((r as FollowUp).follow_up_id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'follow_up_id', header: 'ID', render: (r: FollowUp) => r.follow_up_id },
            { key: 'reflection_id', header: 'Reflection', render: (r: FollowUp) => r.reflection_id },
            { key: 'action_title', header: 'Action', render: (r: FollowUp) => r.action_title },
            { key: 'owner', header: 'Owner', render: (r: FollowUp) => r.owner },
            { key: 'due_date', header: 'Due', render: (r: FollowUp) => r.due_date },
            { key: 'completed_date', header: 'Done', render: (r: FollowUp) => r.completed_date ?? '-' },
            { key: 'state', header: 'State', render: (r: FollowUp) => r.state },
            { key: 'effort_hours', header: 'Hrs', render: (r: FollowUp) => String(r.effort_hours) },
            { key: 'business_lift_score', header: 'Lift', render: (r: FollowUp) => String(r.business_lift_score) },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Overdue follow-ups</h2>
        <DataTable
          rows={overdue}
          rowKey={(r, i) => String((r as Overdue).follow_up_id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'follow_up_id', header: 'ID', render: (r: Overdue) => r.follow_up_id },
            { key: 'action_title', header: 'Action', render: (r: Overdue) => r.action_title },
            { key: 'owner', header: 'Owner', render: (r: Overdue) => r.owner },
            { key: 'due_date', header: 'Due', render: (r: Overdue) => r.due_date },
            { key: 'days_overdue', header: 'Days overdue', render: (r: Overdue) => String(r.days_overdue) },
            { key: 'state', header: 'State', render: (r: Overdue) => r.state },
            { key: 'business_lift_score', header: 'Lift', render: (r: Overdue) => String(r.business_lift_score) },
          ]}
        />
      </section>
    </div>
  );
}
