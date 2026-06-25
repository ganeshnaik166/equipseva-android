import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_events: number;
  approved_recurring: number;
  rejected: number;
  total_savings_rupees: number;
  avg_satisfaction: number;
};

type EventRow = {
  id: string;
  event_month: string;
  customer_org: string;
  equipment_model: string;
  original_part_name: string;
  substitute_part_name: string;
  substitute_source: string;
  fit_quality: string;
  performance_delta_pct: number;
  cost_savings_rupees: number;
  verdict: string;
  approved_by_engineer: string;
};

type FeedbackRow = {
  id: string;
  customer_org: string;
  equipment_model: string;
  substitute_part_name: string;
  customer_contact: string;
  customer_role: string;
  satisfaction_score: number;
  would_repeat: boolean;
  reported_issues: string;
  follow_up_required: boolean;
};

type FitRow = {
  fit_quality: string;
  count: number;
  avg_savings_rupees: number;
  avg_satisfaction: number;
};

type SourceRow = {
  substitute_source: string;
  events_count: number;
  total_savings_rupees: number;
  avg_performance_delta: number;
  approval_rate_pct: number;
};

type FollowupRow = {
  id: string;
  customer_org: string;
  equipment_model: string;
  substitute_part_name: string;
  satisfaction_score: number;
  reported_issues: string;
  verdict: string;
};

type CustomerRow = {
  customer_org: string;
  events_count: number;
  total_savings_rupees: number;
  avg_satisfaction: number;
};

type VerdictRow = {
  verdict: string;
  count: number;
  total_savings_rupees: number;
};

function fmt(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return new Intl.NumberFormat('en-IN').format(Number(n));
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, eventsRes, feedbackRes, fitRes, sourceRes, followupRes, customerRes, verdictRes] = await Promise.all([
    supabase.rpc('r2704_overview_kpis'),
    supabase.rpc('r2704_events_list'),
    supabase.rpc('r2704_feedback_list'),
    supabase.rpc('r2704_fit_quality_breakdown'),
    supabase.rpc('r2704_source_performance'),
    supabase.rpc('r2704_followup_required'),
    supabase.rpc('r2704_top_savings_customers'),
    supabase.rpc('r2704_verdict_distribution'),
  ]);

  const kpi: Kpi = (kpisRes.data?.[0] ?? { total_events: 0, approved_recurring: 0, rejected: 0, total_savings_rupees: 0, avg_satisfaction: 0 }) as Kpi;
  const events: EventRow[] = (eventsRes.data ?? []) as EventRow[];
  const feedback: FeedbackRow[] = (feedbackRes.data ?? []) as FeedbackRow[];
  const fits: FitRow[] = (fitRes.data ?? []) as FitRow[];
  const sources: SourceRow[] = (sourceRes.data ?? []) as SourceRow[];
  const followups: FollowupRow[] = (followupRes.data ?? []) as FollowupRow[];
  const customers: CustomerRow[] = (customerRes.data ?? []) as CustomerRow[];
  const verdicts: VerdictRow[] = (verdictRes.data ?? []) as VerdictRow[];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Customer Monthly Spare Part Substitution Quality</h1>
        <p className="text-sm text-gray-600">
          Equipment × original × substitute × fit quality × customer feedback × verdict
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Total Events</div>
          <div className="text-2xl font-semibold">{fmt(kpi.total_events)}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Approved Recurring</div>
          <div className="text-2xl font-semibold">{fmt(kpi.approved_recurring)}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Rejected</div>
          <div className="text-2xl font-semibold">{fmt(kpi.rejected)}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Total Savings (₹)</div>
          <div className="text-2xl font-semibold">₹{fmt(kpi.total_savings_rupees)}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Avg Satisfaction (1-10)</div>
          <div className="text-2xl font-semibold">{Number(kpi.avg_satisfaction ?? 0).toFixed(2)}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Substitution Events</h2>
        <DataTable
          rows={events}
          columns={[
            { key: 'event_month', header: 'Month', render: (r: EventRow) => r.event_month },
            { key: 'customer_org', header: 'Customer', render: (r: EventRow) => r.customer_org },
            { key: 'equipment_model', header: 'Equipment', render: (r: EventRow) => r.equipment_model },
            { key: 'original_part_name', header: 'Original Part', render: (r: EventRow) => r.original_part_name },
            { key: 'substitute_part_name', header: 'Substitute', render: (r: EventRow) => r.substitute_part_name },
            { key: 'substitute_source', header: 'Source', render: (r: EventRow) => r.substitute_source },
            { key: 'fit_quality', header: 'Fit', render: (r: EventRow) => r.fit_quality },
            { key: 'performance_delta_pct', header: 'Perf %', render: (r: EventRow) => `${Number(r.performance_delta_pct).toFixed(2)}%` },
            { key: 'cost_savings_rupees', header: 'Savings', render: (r: EventRow) => `₹${fmt(r.cost_savings_rupees)}` },
            { key: 'verdict', header: 'Verdict', render: (r: EventRow) => r.verdict },
            { key: 'approved_by_engineer', header: 'Engineer', render: (r: EventRow) => r.approved_by_engineer },
          ]}
          emptyMessage="No data"
          rowKey={(r: EventRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Customer Feedback</h2>
        <DataTable
          rows={feedback}
          columns={[
            { key: 'customer_org', header: 'Customer', render: (r: FeedbackRow) => r.customer_org },
            { key: 'equipment_model', header: 'Equipment', render: (r: FeedbackRow) => r.equipment_model },
            { key: 'substitute_part_name', header: 'Substitute', render: (r: FeedbackRow) => r.substitute_part_name },
            { key: 'customer_contact', header: 'Contact', render: (r: FeedbackRow) => r.customer_contact },
            { key: 'customer_role', header: 'Role', render: (r: FeedbackRow) => r.customer_role },
            { key: 'satisfaction_score', header: 'Score', render: (r: FeedbackRow) => String(r.satisfaction_score) },
            { key: 'would_repeat', header: 'Repeat?', render: (r: FeedbackRow) => r.would_repeat ? 'Yes' : 'No' },
            { key: 'reported_issues', header: 'Issues', render: (r: FeedbackRow) => r.reported_issues },
            { key: 'follow_up_required', header: 'Follow-up', render: (r: FeedbackRow) => r.follow_up_required ? 'Yes' : 'No' },
          ]}
          emptyMessage="No data"
          rowKey={(r: FeedbackRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Fit Quality Breakdown</h2>
        <DataTable
          rows={fits}
          columns={[
            { key: 'fit_quality', header: 'Fit Quality', render: (r: FitRow) => r.fit_quality },
            { key: 'count', header: 'Count', render: (r: FitRow) => fmt(r.count) },
            { key: 'avg_savings_rupees', header: 'Avg Savings', render: (r: FitRow) => `₹${fmt(r.avg_savings_rupees)}` },
            { key: 'avg_satisfaction', header: 'Avg Satisfaction', render: (r: FitRow) => Number(r.avg_satisfaction ?? 0).toFixed(2) },
          ]}
          emptyMessage="No data"
          rowKey={(r: FitRow, i: number) => String(r.fit_quality ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Substitute Source Performance</h2>
        <DataTable
          rows={sources}
          columns={[
            { key: 'substitute_source', header: 'Source', render: (r: SourceRow) => r.substitute_source },
            { key: 'events_count', header: 'Events', render: (r: SourceRow) => fmt(r.events_count) },
            { key: 'total_savings_rupees', header: 'Total Savings', render: (r: SourceRow) => `₹${fmt(r.total_savings_rupees)}` },
            { key: 'avg_performance_delta', header: 'Avg Perf Delta %', render: (r: SourceRow) => `${Number(r.avg_performance_delta ?? 0).toFixed(2)}%` },
            { key: 'approval_rate_pct', header: 'Approval Rate %', render: (r: SourceRow) => `${Number(r.approval_rate_pct ?? 0).toFixed(2)}%` },
          ]}
          emptyMessage="No data"
          rowKey={(r: SourceRow, i: number) => String(r.substitute_source ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Follow-up Required (Score &lt;= threshold)</h2>
        <DataTable
          rows={followups}
          columns={[
            { key: 'customer_org', header: 'Customer', render: (r: FollowupRow) => r.customer_org },
            { key: 'equipment_model', header: 'Equipment', render: (r: FollowupRow) => r.equipment_model },
            { key: 'substitute_part_name', header: 'Substitute', render: (r: FollowupRow) => r.substitute_part_name },
            { key: 'satisfaction_score', header: 'Score', render: (r: FollowupRow) => String(r.satisfaction_score) },
            { key: 'reported_issues', header: 'Issues', render: (r: FollowupRow) => r.reported_issues },
            { key: 'verdict', header: 'Verdict', render: (r: FollowupRow) => r.verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r: FollowupRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Savings Customers</h2>
        <DataTable
          rows={customers}
          columns={[
            { key: 'customer_org', header: 'Customer', render: (r: CustomerRow) => r.customer_org },
            { key: 'events_count', header: 'Events', render: (r: CustomerRow) => fmt(r.events_count) },
            { key: 'total_savings_rupees', header: 'Total Savings', render: (r: CustomerRow) => `₹${fmt(r.total_savings_rupees)}` },
            { key: 'avg_satisfaction', header: 'Avg Satisfaction', render: (r: CustomerRow) => Number(r.avg_satisfaction ?? 0).toFixed(2) },
          ]}
          emptyMessage="No data"
          rowKey={(r: CustomerRow, i: number) => String(r.customer_org ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Verdict Distribution</h2>
        <DataTable
          rows={verdicts}
          columns={[
            { key: 'verdict', header: 'Verdict', render: (r: VerdictRow) => r.verdict },
            { key: 'count', header: 'Count', render: (r: VerdictRow) => fmt(r.count) },
            { key: 'total_savings_rupees', header: 'Total Savings', render: (r: VerdictRow) => `₹${fmt(r.total_savings_rupees)}` },
          ]}
          emptyMessage="No data"
          rowKey={(r: VerdictRow, i: number) => String(r.verdict ?? i)}
        />
      </section>
    </div>
  );
}
