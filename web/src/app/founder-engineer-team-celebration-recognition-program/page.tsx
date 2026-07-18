import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [celebrations, outcomes, topValue, kindDist, statusFunnel, monthlyTrend, ownerLoad] = await Promise.all([
    supabase.rpc('list_celebrations_r2646'),
    supabase.rpc('list_engagement_outcomes_r2646'),
    supabase.rpc('top_value_focus_r2646'),
    supabase.rpc('celebration_kind_distribution_r2646'),
    supabase.rpc('status_funnel_r2646'),
    supabase.rpc('monthly_celebration_trend_r2646'),
    supabase.rpc('owner_load_r2646'),
  ]);

  const celebrationCols: Column<any>[] = [
    { key: 'celebrated_at', header: 'Celebrated', render: (r: any) => new Date(r.celebrated_at).toLocaleString() },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id).slice(0, 8) },
    { key: 'celebration_kind', header: 'Kind', render: (r: any) => r.celebration_kind },
    { key: 'value_rupees', header: 'Value (Rs)', render: (r: any) => `Rs ${r.value_rupees}` },
    { key: 'team_present_count', header: 'Team present', render: (r: any) => r.team_present_count },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const outcomeCols: Column<any>[] = [
    { key: 'observed_at', header: 'Observed', render: (r: any) => new Date(r.observed_at).toLocaleString() },
    { key: 'celebration_id', header: 'Celebration', render: (r: any) => String(r.celebration_id).slice(0, 8) },
    { key: 'engagement_kind', header: 'Engagement', render: (r: any) => r.engagement_kind },
    { key: 'retention_signal', header: 'Retention', render: (r: any) => r.retention_signal },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const topValueCols: Column<any>[] = [
    { key: 'celebration_kind', header: 'Kind', render: (r: any) => r.celebration_kind },
    { key: 'celebration_count', header: 'Count', render: (r: any) => r.celebration_count },
    { key: 'total_value_rupees', header: 'Total spend (Rs)', render: (r: any) => `Rs ${r.total_value_rupees}` },
    { key: 'avg_team_present', header: 'Avg team', render: (r: any) => r.avg_team_present },
  ];

  const kindDistCols: Column<any>[] = [
    { key: 'celebration_kind', header: 'Kind', render: (r: any) => r.celebration_kind },
    { key: 'celebration_count', header: 'Count', render: (r: any) => r.celebration_count },
  ];

  const statusFunnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'celebration_count', header: 'Count', render: (r: any) => r.celebration_count },
  ];

  const monthlyTrendCols: Column<any>[] = [
    { key: 'month_bucket', header: 'Month', render: (r: any) => new Date(r.month_bucket).toLocaleDateString() },
    { key: 'celebration_count', header: 'Count', render: (r: any) => r.celebration_count },
    { key: 'total_value_rupees', header: 'Total (Rs)', render: (r: any) => `Rs ${r.total_value_rupees}` },
  ];

  const ownerLoadCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'celebration_count', header: 'Celebrations', render: (r: any) => r.celebration_count },
    { key: 'outcome_count', header: 'Outcomes', render: (r: any) => r.outcome_count },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Team Celebration & Recognition Program</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track personal milestones celebrated with engineers & the engagement &gt; retention signal that follows.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top value focus (spend by kind)</h2>
        <DataTable
          rows={topValue.data ?? []}
          columns={topValueCols}
          emptyMessage="No celebration spend recorded yet."
          rowKey={(r: any, i: number) => String(r.celebration_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Celebration kind distribution</h2>
        <DataTable
          rows={kindDist.data ?? []}
          columns={kindDistCols}
          emptyMessage="No celebrations to distribute."
          rowKey={(r: any, i: number) => String(r.celebration_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status funnel</h2>
        <DataTable
          rows={statusFunnel.data ?? []}
          columns={statusFunnelCols}
          emptyMessage="No status data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly celebration trend</h2>
        <DataTable
          rows={monthlyTrend.data ?? []}
          columns={monthlyTrendCols}
          emptyMessage="No monthly trend yet."
          rowKey={(r: any, i: number) => String(r.month_bucket ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Owner load</h2>
        <DataTable
          rows={ownerLoad.data ?? []}
          columns={ownerLoadCols}
          emptyMessage="No owner load data."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Celebrations</h2>
        <DataTable
          rows={celebrations.data ?? []}
          columns={celebrationCols}
          emptyMessage="No celebrations logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engagement outcomes</h2>
        <DataTable
          rows={outcomes.data ?? []}
          columns={outcomeCols}
          emptyMessage="No engagement outcomes recorded."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
