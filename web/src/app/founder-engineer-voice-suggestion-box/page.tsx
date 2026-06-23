import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  const email = user?.email ?? '';
  const isFounder = email === 'marketingtools@getphyllo.com';

  if (!isFounder) {
    return <div className="p-8 text-red-600">Forbidden — founder only</div>;
  }

  const [inbox, pain, pipeline, impl, voters, ie, velocity] = await Promise.all([
    supabase.rpc('founder_voice_inbox_r2362'),
    supabase.rpc('founder_voice_top_pain_r2362'),
    supabase.rpc('founder_voice_pipeline_r2362'),
    supabase.rpc('founder_voice_impl_rate_r2362'),
    supabase.rpc('founder_voice_top_voters_r2362'),
    supabase.rpc('founder_voice_impact_effort_r2362'),
    supabase.rpc('founder_voice_ship_velocity_r2362'),
  ]);

  const inboxCols: Column<any>[] = [
    { key: 'title', header: 'Title', render: (r) => <span className="font-medium">{r.title}</span> },
    { key: 'category', header: 'Category', render: (r: any) => String(r.category ?? '') },
    { key: 'pain_score', header: 'Pain', render: (r) => <span className={r.pain_score >= 8 ? 'text-red-600 font-bold' : ''}>{r.pain_score}/10</span> },
    { key: 'frequency', header: 'Freq', render: (r: any) => String(r.frequency ?? '') },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '') },
    { key: 'upvotes', header: 'Votes', render: (r: any) => String(r.upvotes ?? '') },
    { key: 'submitted_at', header: 'Submitted', render: (r) => new Date(r.submitted_at).toLocaleDateString() },
  ];

  const painCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r: any) => String(r.category ?? '') },
    { key: 'suggestions_count', header: 'Count', render: (r: any) => String(r.suggestions_count ?? '') },
    { key: 'avg_pain', header: 'Avg Pain', render: (r) => <span className={Number(r.avg_pain) >= 7 ? 'text-red-600' : ''}>{r.avg_pain}</span> },
    { key: 'total_upvotes', header: 'Votes', render: (r: any) => String(r.total_upvotes ?? '') },
  ];

  const pipelineCols: Column<any>[] = [
    { key: 'triage_state', header: 'State', render: (r: any) => String(r.triage_state ?? '') },
    { key: 'ct', header: 'Count', render: (r: any) => String(r.ct ?? '') },
    { key: 'avg_age_days', header: 'Avg Age (d)', render: (r: any) => String(r.avg_age_days ?? '') },
  ];

  const votersCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '') },
    { key: 'submissions', header: 'Submitted', render: (r: any) => String(r.submissions ?? '') },
    { key: 'votes_cast', header: 'Voted', render: (r: any) => String(r.votes_cast ?? '') },
    { key: 'shipped_count', header: 'Shipped', render: (r: any) => String(r.shipped_count ?? '') },
  ];

  const ieCols: Column<any>[] = [
    { key: 'title', header: 'Title', render: (r: any) => String(r.title ?? '') },
    { key: 'category', header: 'Cat', render: (r: any) => String(r.category ?? '') },
    { key: 'impact_score', header: 'Impact', render: (r: any) => String(r.impact_score ?? '') },
    { key: 'effort_score', header: 'Effort', render: (r: any) => String(r.effort_score ?? '') },
    { key: 'ratio', header: 'I/E', render: (r) => <span className="font-bold">{r.ratio}</span> },
    { key: 'triage_state', header: 'State', render: (r: any) => String(r.triage_state ?? '') },
  ];

  const velCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r) => new Date(r.week_start).toLocaleDateString() },
    { key: 'shipped_ct', header: 'Shipped', render: (r: any) => String(r.shipped_ct ?? '') },
    { key: 'avg_days_to_ship', header: 'Avg Days', render: (r: any) => String(r.avg_days_to_ship ?? '') },
  ];

  const implRow = impl.data?.[0];

  return (
    <div className="p-8 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Engineer Voice — Suggestion Box</h1>
        <p className="text-sm text-gray-600">Field improvement ideas from engineers — triage & ship rate</p>
      </div>

      {implRow && (
        <div className="grid grid-cols-5 gap-4">
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Total</div>
            <div className="text-2xl font-bold">{implRow.total}</div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Shipped</div>
            <div className="text-2xl font-bold text-green-600">{implRow.shipped}</div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">In Flight</div>
            <div className="text-2xl font-bold text-blue-600">{implRow.in_flight}</div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Rejected</div>
            <div className="text-2xl font-bold text-gray-600">{implRow.rejected}</div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Impl Rate</div>
            <div className="text-2xl font-bold">{implRow.impl_pct}%</div>
          </div>
        </div>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-2">New — needs triage</h2>
        <DataTable
          rows={inbox.data ?? []}
          columns={inboxCols}
          emptyMessage="Inbox empty"
          rowKey={(r: any) => r.id}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top pain by category</h2>
        <DataTable
          rows={pain.data ?? []}
          columns={painCols}
          emptyMessage="No data"
          rowKey={(r: any) => r.category}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pipeline state</h2>
        <DataTable
          rows={pipeline.data ?? []}
          columns={pipelineCols}
          emptyMessage="No suggestions yet"
          rowKey={(r: any) => r.triage_state}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Impact / Effort — quick wins</h2>
        <DataTable
          rows={ie.data ?? []}
          columns={ieCols}
          emptyMessage="No scored suggestions yet"
          rowKey={(r: any) => r.id}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top contributors</h2>
        <DataTable
          rows={voters.data ?? []}
          columns={votersCols}
          emptyMessage="No contributors yet"
          rowKey={(r: any) => r.engineer_email}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Ship velocity (12w)</h2>
        <DataTable
          rows={velocity.data ?? []}
          columns={velCols}
          emptyMessage="Nothing shipped yet"
          rowKey={(r: any) => r.week_start}
        />
      </section>
    </div>
  );
}
