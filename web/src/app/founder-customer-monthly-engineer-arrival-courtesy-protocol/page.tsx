import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = { total_visits: number; avg_courtesy: number; avg_wait: number; delighted: number; complaints: number; open_actions: number };
type Visit = { id: string; visit_code: string; job_code: string; customer_name: string; engineer_name: string; city: string; visit_at: string; greeting_quality: string; intro_completeness: string; wait_minutes: number; courtesy_score: number; outcome: string; notes: string | null };
type Greeting = { greeting_quality: string; visits: number; avg_score: number; avg_wait: number };
type Engineer = { engineer_name: string; visits: number; avg_score: number; complaints: number };
type Outcome = { outcome: string; visits: number; avg_wait: number };
type Action = { id: string; visit_code: string; action_type: string; owner: string; due_on: string; status: string; impact_rupees: number; notes: string | null };
type Problem = { visit_code: string; engineer_name: string; courtesy_score: number; outcome: string; notes: string | null };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [ov, vis, gr, en, oc, ac, pr] = await Promise.all([
    supabase.rpc('r2752_overview'),
    supabase.rpc('r2752_visits'),
    supabase.rpc('r2752_by_greeting'),
    supabase.rpc('r2752_by_engineer'),
    supabase.rpc('r2752_by_outcome'),
    supabase.rpc('r2752_actions'),
    supabase.rpc('r2752_top_problems'),
  ]);
  const overview: Overview = (ov.data?.[0] as Overview) ?? { total_visits: 0, avg_courtesy: 0, avg_wait: 0, delighted: 0, complaints: 0, open_actions: 0 };
  const visits: Visit[] = (vis.data as Visit[]) ?? [];
  const greetings: Greeting[] = (gr.data as Greeting[]) ?? [];
  const engineers: Engineer[] = (en.data as Engineer[]) ?? [];
  const outcomes: Outcome[] = (oc.data as Outcome[]) ?? [];
  const actions: Action[] = (ac.data as Action[]) ?? [];
  const problems: Problem[] = (pr.data as Problem[]) ?? [];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Monthly Engineer Arrival Courtesy Protocol</h1>
        <p className="text-sm text-gray-600">Job × greeting × intro × wait × courtesy score × outcome — monthly customer-facing courtesy audit.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <Kpi label="Total Visits" value={String(overview.total_visits)} />
        <Kpi label="Avg Courtesy" value={String(overview.avg_courtesy)} />
        <Kpi label="Avg Wait (min)" value={String(overview.avg_wait)} />
        <Kpi label="Delighted" value={String(overview.delighted)} />
        <Kpi label="Complaints" value={String(overview.complaints)} />
        <Kpi label="Open Actions" value={String(overview.open_actions)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Visits</h2>
        <DataTable<Visit>
          rows={visits}
          columns={[
            { key: 'visit_code', header: 'Visit', render: (r) => r.visit_code },
            { key: 'job_code', header: 'Job', render: (r) => r.job_code },
            { key: 'customer_name', header: 'Customer', render: (r) => r.customer_name },
            { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
            { key: 'city', header: 'City', render: (r) => r.city },
            { key: 'greeting_quality', header: 'Greeting', render: (r) => r.greeting_quality },
            { key: 'intro_completeness', header: 'Intro', render: (r) => r.intro_completeness },
            { key: 'wait_minutes', header: 'Wait (min)', render: (r) => String(r.wait_minutes) },
            { key: 'courtesy_score', header: 'Score', render: (r) => String(r.courtesy_score) },
            { key: 'outcome', header: 'Outcome', render: (r) => r.outcome },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">By Greeting Quality</h2>
          <DataTable<Greeting>
            rows={greetings}
            columns={[
              { key: 'greeting_quality', header: 'Greeting', render: (r) => r.greeting_quality },
              { key: 'visits', header: 'Visits', render: (r) => String(r.visits) },
              { key: 'avg_score', header: 'Avg Score', render: (r) => String(r.avg_score) },
              { key: 'avg_wait', header: 'Avg Wait', render: (r) => String(r.avg_wait) },
            ]}
            emptyMessage="No data"
            rowKey={(r, i) => String(i)}
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-2">By Engineer</h2>
          <DataTable<Engineer>
            rows={engineers}
            columns={[
              { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
              { key: 'visits', header: 'Visits', render: (r) => String(r.visits) },
              { key: 'avg_score', header: 'Avg Score', render: (r) => String(r.avg_score) },
              { key: 'complaints', header: 'Complaints', render: (r) => String(r.complaints) },
            ]}
            emptyMessage="No data"
            rowKey={(r, i) => String(i)}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By Outcome</h2>
        <DataTable<Outcome>
          rows={outcomes}
          columns={[
            { key: 'outcome', header: 'Outcome', render: (r) => r.outcome },
            { key: 'visits', header: 'Visits', render: (r) => String(r.visits) },
            { key: 'avg_wait', header: 'Avg Wait', render: (r) => String(r.avg_wait) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Problems (score &lt; 60 or complaint)</h2>
        <DataTable<Problem>
          rows={problems}
          columns={[
            { key: 'visit_code', header: 'Visit', render: (r) => r.visit_code },
            { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
            { key: 'courtesy_score', header: 'Score', render: (r) => String(r.courtesy_score) },
            { key: 'outcome', header: 'Outcome', render: (r) => r.outcome },
            { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '' },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Action Queue</h2>
        <DataTable<Action>
          rows={actions}
          columns={[
            { key: 'visit_code', header: 'Visit', render: (r) => r.visit_code },
            { key: 'action_type', header: 'Action', render: (r) => r.action_type },
            { key: 'owner', header: 'Owner', render: (r) => r.owner },
            { key: 'due_on', header: 'Due', render: (r) => r.due_on },
            { key: 'status', header: 'Status', render: (r) => r.status },
            { key: 'impact_rupees', header: 'Impact (Rs)', render: (r) => String(r.impact_rupees) },
            { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '' },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border bg-white p-3">
      <div className="text-xs text-gray-500">{label}</div>
      <div className="text-xl font-semibold">{value}</div>
    </div>
  );
}
