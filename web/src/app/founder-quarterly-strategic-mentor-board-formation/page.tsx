import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_candidates: number;
  onboard_count: number;
  invited_count: number;
  pending_count: number;
  total_ask_rupees: number;
  total_commit_hours: number;
  avg_insight_score: number;
  total_meetings: number;
  total_impact_rupees: number;
};

type Candidate = {
  id: string;
  mentor_name: string;
  domain: string;
  city: string;
  ask_summary: string;
  ask_value_rupees: number;
  commit_hours_per_quarter: number;
  cadence: string;
  insight_score: number;
  verdict: string;
};

type DomainRow = {
  domain: string;
  candidates: number;
  onboard: number;
  total_ask_rupees: number;
  avg_insight_score: number;
};

type Meeting = {
  id: string;
  mentor_name: string;
  domain: string;
  meeting_date: string;
  duration_min: number;
  topic: string;
  insight_text: string;
  action_taken: string;
  impact_rupees: number;
  follow_up_due: string | null;
};

type CadenceRow = {
  cadence: string;
  onboard: number;
  total_quarterly_hours: number;
};

type FollowupRow = {
  id: string;
  mentor_name: string;
  topic: string;
  action_taken: string;
  follow_up_due: string;
  days_until_due: number;
};

type InsightRow = {
  id: string;
  mentor_name: string;
  domain: string;
  topic: string;
  insight_text: string;
  impact_rupees: number;
  action_taken: string;
};

function rupees(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, candRes, domRes, meetRes, cadRes, followRes, topRes] = await Promise.all([
    supabase.rpc('get_mentor_board_kpis_r2873'),
    supabase.rpc('list_mentor_candidates_r2873'),
    supabase.rpc('get_mentor_domain_rollup_r2873'),
    supabase.rpc('list_mentor_meetings_r2873'),
    supabase.rpc('get_mentor_cadence_rollup_r2873'),
    supabase.rpc('list_mentor_followups_r2873'),
    supabase.rpc('list_top_mentor_insights_r2873'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] ?? {
    total_candidates: 0,
    onboard_count: 0,
    invited_count: 0,
    pending_count: 0,
    total_ask_rupees: 0,
    total_commit_hours: 0,
    avg_insight_score: 0,
    total_meetings: 0,
    total_impact_rupees: 0,
  }) as Kpi;

  const candidates: Candidate[] = (candRes.data ?? []) as Candidate[];
  const domains: DomainRow[] = (domRes.data ?? []) as DomainRow[];
  const meetings: Meeting[] = (meetRes.data ?? []) as Meeting[];
  const cadences: CadenceRow[] = (cadRes.data ?? []) as CadenceRow[];
  const followups: FollowupRow[] = (followRes.data ?? []) as FollowupRow[];
  const topInsights: InsightRow[] = (topRes.data ?? []) as InsightRow[];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Quarterly Strategic Mentor Board Formation</h1>
        <p className="text-sm text-gray-600">
          Round r2873 · mentor × domain × ask × commit × cadence × insights × verdict
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Candidates</div>
          <div className="text-2xl font-semibold">{kpi.total_candidates}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Onboard</div>
          <div className="text-2xl font-semibold">{kpi.onboard_count}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Invited</div>
          <div className="text-2xl font-semibold">{kpi.invited_count}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Pending</div>
          <div className="text-2xl font-semibold">{kpi.pending_count}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Total Ask</div>
          <div className="text-2xl font-semibold">{rupees(kpi.total_ask_rupees)}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Commit Hours / Qtr</div>
          <div className="text-2xl font-semibold">{kpi.total_commit_hours}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Avg Insight Score</div>
          <div className="text-2xl font-semibold">{Number(kpi.avg_insight_score).toFixed(1)}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Realized Impact</div>
          <div className="text-2xl font-semibold">{rupees(kpi.total_impact_rupees)}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Mentor candidates</h2>
        <DataTable
          rows={candidates}
          columns={[
            { key: 'mentor_name', header: 'Mentor', render: (r: Candidate) => r.mentor_name },
            { key: 'domain', header: 'Domain', render: (r: Candidate) => r.domain },
            { key: 'city', header: 'City', render: (r: Candidate) => r.city },
            { key: 'ask_summary', header: 'Ask', render: (r: Candidate) => r.ask_summary },
            { key: 'ask_value_rupees', header: 'Ask value', render: (r: Candidate) => rupees(r.ask_value_rupees) },
            { key: 'commit_hours_per_quarter', header: 'Hrs/Qtr', render: (r: Candidate) => String(r.commit_hours_per_quarter) },
            { key: 'cadence', header: 'Cadence', render: (r: Candidate) => r.cadence },
            { key: 'insight_score', header: 'Score', render: (r: Candidate) => String(r.insight_score) },
            { key: 'verdict', header: 'Verdict', render: (r: Candidate) => r.verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r: Candidate, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Domain rollup</h2>
        <DataTable
          rows={domains}
          columns={[
            { key: 'domain', header: 'Domain', render: (r: DomainRow) => r.domain },
            { key: 'candidates', header: 'Candidates', render: (r: DomainRow) => String(r.candidates) },
            { key: 'onboard', header: 'Onboard', render: (r: DomainRow) => String(r.onboard) },
            { key: 'total_ask_rupees', header: 'Total ask', render: (r: DomainRow) => rupees(r.total_ask_rupees) },
            { key: 'avg_insight_score', header: 'Avg score', render: (r: DomainRow) => Number(r.avg_insight_score).toFixed(1) },
          ]}
          emptyMessage="No data"
          rowKey={(r: DomainRow, i: number) => String(r.domain ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Cadence rollup</h2>
        <DataTable
          rows={cadences}
          columns={[
            { key: 'cadence', header: 'Cadence', render: (r: CadenceRow) => r.cadence },
            { key: 'onboard', header: 'Onboard mentors', render: (r: CadenceRow) => String(r.onboard) },
            { key: 'total_quarterly_hours', header: 'Total hrs/qtr', render: (r: CadenceRow) => String(r.total_quarterly_hours) },
          ]}
          emptyMessage="No data"
          rowKey={(r: CadenceRow, i: number) => String(r.cadence ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent meetings & insights</h2>
        <DataTable
          rows={meetings}
          columns={[
            { key: 'meeting_date', header: 'Date', render: (r: Meeting) => r.meeting_date },
            { key: 'mentor_name', header: 'Mentor', render: (r: Meeting) => r.mentor_name },
            { key: 'domain', header: 'Domain', render: (r: Meeting) => r.domain },
            { key: 'duration_min', header: 'Min', render: (r: Meeting) => String(r.duration_min) },
            { key: 'topic', header: 'Topic', render: (r: Meeting) => r.topic },
            { key: 'insight_text', header: 'Insight', render: (r: Meeting) => r.insight_text },
            { key: 'action_taken', header: 'Action', render: (r: Meeting) => r.action_taken },
            { key: 'impact_rupees', header: 'Impact', render: (r: Meeting) => rupees(r.impact_rupees) },
            { key: 'follow_up_due', header: 'Follow-up', render: (r: Meeting) => r.follow_up_due ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: Meeting, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Follow-ups pending</h2>
        <DataTable
          rows={followups}
          columns={[
            { key: 'mentor_name', header: 'Mentor', render: (r: FollowupRow) => r.mentor_name },
            { key: 'topic', header: 'Topic', render: (r: FollowupRow) => r.topic },
            { key: 'action_taken', header: 'Status', render: (r: FollowupRow) => r.action_taken },
            { key: 'follow_up_due', header: 'Due', render: (r: FollowupRow) => r.follow_up_due },
            { key: 'days_until_due', header: 'Days left', render: (r: FollowupRow) => String(r.days_until_due) },
          ]}
          emptyMessage="No data"
          rowKey={(r: FollowupRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top insights by impact</h2>
        <DataTable
          rows={topInsights}
          columns={[
            { key: 'mentor_name', header: 'Mentor', render: (r: InsightRow) => r.mentor_name },
            { key: 'domain', header: 'Domain', render: (r: InsightRow) => r.domain },
            { key: 'topic', header: 'Topic', render: (r: InsightRow) => r.topic },
            { key: 'insight_text', header: 'Insight', render: (r: InsightRow) => r.insight_text },
            { key: 'impact_rupees', header: 'Impact', render: (r: InsightRow) => rupees(r.impact_rupees) },
            { key: 'action_taken', header: 'Action', render: (r: InsightRow) => r.action_taken },
          ]}
          emptyMessage="No data"
          rowKey={(r: InsightRow, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
