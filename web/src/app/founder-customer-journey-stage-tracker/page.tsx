import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function CustomerJourneyStageTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [dist, dur, risk, recent, stuck, advocates, kpi] = await Promise.all([
    supabase.rpc('r2360_stage_distribution'),
    supabase.rpc('r2360_avg_stage_duration'),
    supabase.rpc('r2360_at_risk_list'),
    supabase.rpc('r2360_recent_transitions', { p_limit: 50 }),
    supabase.rpc('r2360_stuck_customers', { p_min_days: 30 }),
    supabase.rpc('r2360_advocates_list'),
    supabase.rpc('r2360_kpi_summary'),
  ]);

  const distRows = (dist.data ?? []) as any[];
  const durRows = (dur.data ?? []) as any[];
  const riskRows = (risk.data ?? []) as any[];
  const recentRows = (recent.data ?? []) as any[];
  const stuckRows = (stuck.data ?? []) as any[];
  const advocateRows = (advocates.data ?? []) as any[];
  const kpiRow = (kpi.data ?? [])[0] as any | undefined;

  const distCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r) => <span className="font-medium capitalize">{r.stage}</span> },
    { key: 'customer_count', header: 'Customers', render: (r) => r.customer_count ?? 0 },
    { key: 'total_arr_rupees', header: 'ARR (Rs)', render: (r) => Number(r.total_arr_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'avg_health', header: 'Avg health', render: (r) => r.avg_health ?? '-' },
    { key: 'at_risk_count', header: 'At risk', render: (r) => r.at_risk_count ?? 0 },
  ];

  const durCols: Column<any>[] = [
    { key: 'stage', header: 'From stage', render: (r) => <span className="capitalize">{r.stage}</span> },
    { key: 'avg_days', header: 'Avg days in stage', render: (r) => r.avg_days ?? '-' },
    { key: 'samples', header: 'Transitions', render: (r) => r.samples ?? 0 },
  ];

  const riskCols: Column<any>[] = [
    { key: 'customer_name', header: 'Customer', render: (r) => r.customer_name },
    { key: 'customer_email', header: 'Email', render: (r) => r.customer_email },
    { key: 'current_stage', header: 'Stage', render: (r) => <span className="capitalize">{r.current_stage}</span> },
    { key: 'health_score', header: 'Health', render: (r) => <span className={r.health_score < 40 ? 'text-red-600 font-semibold' : ''}>{r.health_score}</span> },
    { key: 'arr_rupees', header: 'ARR (Rs)', render: (r) => Number(r.arr_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'owner_csm_email', header: 'CSM', render: (r) => r.owner_csm_email ?? '-' },
    { key: 'next_action', header: 'Next action', render: (r) => r.next_action ?? '-' },
    { key: 'next_action_due_at', header: 'Due', render: (r) => r.next_action_due_at ? new Date(r.next_action_due_at).toLocaleDateString() : '-' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'customer_name', header: 'Customer', render: (r) => r.customer_name },
    { key: 'from_stage', header: 'From', render: (r) => <span className="capitalize">{r.from_stage ?? '-'}</span> },
    { key: 'to_stage', header: 'To', render: (r) => <span className="capitalize font-medium">{r.to_stage}</span> },
    { key: 'days_in_prev_stage', header: 'Days in prev', render: (r) => r.days_in_prev_stage ?? '-' },
    { key: 'reason', header: 'Reason', render: (r) => r.reason ?? '-' },
    { key: 'actor_email', header: 'Actor', render: (r) => r.actor_email ?? '-' },
    { key: 'transitioned_at', header: 'When', render: (r) => new Date(r.transitioned_at).toLocaleString() },
  ];

  const stuckCols: Column<any>[] = [
    { key: 'customer_name', header: 'Customer', render: (r) => r.customer_name },
    { key: 'current_stage', header: 'Stuck in', render: (r) => <span className="capitalize">{r.current_stage}</span> },
    { key: 'days_in_stage', header: 'Days', render: (r) => <span className={r.days_in_stage >= 60 ? 'text-red-600 font-semibold' : 'text-amber-700'}>{r.days_in_stage}</span> },
    { key: 'arr_rupees', header: 'ARR (Rs)', render: (r) => Number(r.arr_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'health_score', header: 'Health', render: (r) => r.health_score },
    { key: 'owner_csm_email', header: 'CSM', render: (r) => r.owner_csm_email ?? '-' },
  ];

  const advCols: Column<any>[] = [
    { key: 'customer_name', header: 'Advocate', render: (r) => r.customer_name },
    { key: 'organization_name', header: 'Org', render: (r) => r.organization_name ?? '-' },
    { key: 'customer_email', header: 'Email', render: (r) => r.customer_email },
    { key: 'arr_rupees', header: 'ARR (Rs)', render: (r) => Number(r.arr_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'health_score', header: 'Health', render: (r) => r.health_score },
    { key: 'stage_entered_at', header: 'Advocate since', render: (r) => new Date(r.stage_entered_at).toLocaleDateString() },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Customer journey-stage tracker</h1>
        <p className="text-sm text-gray-600">Where each customer sits across prospect =&gt; onboard =&gt; active =&gt; renewal =&gt; advocate, plus time-in-stage and risk signals.</p>
      </header>

      {kpiRow && (
        <section className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-3">
          <div className="rounded border p-3"><div className="text-xs text-gray-500">Customers</div><div className="text-lg font-semibold">{kpiRow.total_customers}</div></div>
          <div className="rounded border p-3"><div className="text-xs text-gray-500">Total ARR (Rs)</div><div className="text-lg font-semibold">{Number(kpiRow.total_arr_rupees ?? 0).toLocaleString('en-IN')}</div></div>
          <div className="rounded border p-3"><div className="text-xs text-gray-500">At risk</div><div className="text-lg font-semibold text-red-600">{kpiRow.at_risk_count}</div></div>
          <div className="rounded border p-3"><div className="text-xs text-gray-500">Avg health</div><div className="text-lg font-semibold">{kpiRow.avg_health}</div></div>
          <div className="rounded border p-3"><div className="text-xs text-gray-500">Advocates</div><div className="text-lg font-semibold text-green-700">{kpiRow.advocate_count}</div></div>
          <div className="rounded border p-3"><div className="text-xs text-gray-500">Prospects</div><div className="text-lg font-semibold">{kpiRow.prospect_count}</div></div>
          <div className="rounded border p-3"><div className="text-xs text-gray-500">In renewal</div><div className="text-lg font-semibold">{kpiRow.renewal_count}</div></div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-medium mb-2">Stage distribution</h2>
        <DataTable rows={distRows} emptyMessage="No customer journey rows yet." rowKey={(r: any) => r.stage} columns={distCols} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Average time in each stage</h2>
        <DataTable rows={durRows} emptyMessage="No transitions recorded yet." rowKey={(r: any) => r.stage} columns={durCols} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">At-risk customers</h2>
        <DataTable rows={riskRows} emptyMessage="Nobody flagged as at-risk." rowKey={(r: any) => r.id} columns={riskCols} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Stuck customers (&gt;= 30 days in stage)</h2>
        <DataTable rows={stuckRows} emptyMessage="No stuck customers." rowKey={(r: any) => r.id} columns={stuckCols} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recent stage transitions</h2>
        <DataTable rows={recentRows} emptyMessage="No transitions yet." rowKey={(r: any) => r.id} columns={recentCols} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Advocates</h2>
        <DataTable rows={advocateRows} emptyMessage="No advocates yet." rowKey={(r: any) => r.id} columns={advCols} />
      </section>
    </div>
  );
}
