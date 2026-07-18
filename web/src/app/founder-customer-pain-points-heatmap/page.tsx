import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function CustomerPainPointsHeatmapPage() {
  const supabase = await getSupabaseServerClient();

  const [painPointsRes, fixActionsRes, killPriorityRes, gridRes, topHospitalsRes, kindRes, velocityRes] = await Promise.all([
    supabase.rpc('list_pain_points_r2476'),
    supabase.rpc('list_fix_actions_r2476'),
    supabase.rpc('top_kill_priority_r2476'),
    supabase.rpc('severity_x_frequency_grid_r2476'),
    supabase.rpc('top_hospitals_by_pain_r2476'),
    supabase.rpc('kind_breakdown_r2476'),
    supabase.rpc('monthly_fix_velocity_r2476'),
  ]);

  const painPoints = (painPointsRes.data ?? []) as any[];
  const fixActions = (fixActionsRes.data ?? []) as any[];
  const killPriority = (killPriorityRes.data ?? []) as any[];
  const grid = (gridRes.data ?? []) as any[];
  const topHospitals = (topHospitalsRes.data ?? []) as any[];
  const kindBreakdown = (kindRes.data ?? []) as any[];
  const velocity = (velocityRes.data ?? []) as any[];

  const fmtINR = (n: number | null | undefined) =>
    n == null ? '-' : `₹${Number(n).toLocaleString('en-IN')}`;
  const fmtDate = (d: string | null | undefined) =>
    d ? new Date(d).toLocaleDateString('en-IN') : '-';
  const fmtMonth = (d: string | null | undefined) =>
    d ? new Date(d).toLocaleDateString('en-IN', { year: 'numeric', month: 'short' }) : '-';

  const painCols: Column<any>[] = [
    { key: 'pain_point_signature', header: 'Pain Point', render: (r: any) => r.pain_point_signature },
    { key: 'pain_kind', header: 'Kind', render: (r: any) => r.pain_kind },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'frequency_score', header: 'Freq', render: (r: any) => `${r.frequency_score}/100` },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity },
    { key: 'associated_revenue_rupees', header: 'Revenue at risk', render: (r: any) => fmtINR(r.associated_revenue_rupees) },
    { key: 'kill_priority', header: 'Kill #', render: (r: any) => `P${r.kill_priority}` },
    { key: 'fix_team_owner_email', header: 'Owner', render: (r: any) => r.fix_team_owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'reported_at', header: 'Reported', render: (r: any) => fmtDate(r.reported_at) },
    { key: 'fixed_at', header: 'Fixed', render: (r: any) => fmtDate(r.fixed_at) },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'pain_point_signature', header: 'Pain Point', render: (r: any) => r.pain_point_signature ?? '-' },
    { key: 'action_at', header: 'When', render: (r: any) => fmtDate(r.action_at) },
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'action_summary', header: 'Summary', render: (r: any) => r.action_summary },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'follow_up_at', header: 'Follow-up', render: (r: any) => fmtDate(r.follow_up_at) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const killCols: Column<any>[] = [
    { key: 'kill_priority', header: 'Kill #', render: (r: any) => `P${r.kill_priority}` },
    { key: 'pain_point_signature', header: 'Pain Point', render: (r: any) => r.pain_point_signature },
    { key: 'pain_kind', header: 'Kind', render: (r: any) => r.pain_kind },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'frequency_score', header: 'Freq', render: (r: any) => r.frequency_score },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity },
    { key: 'associated_revenue_rupees', header: 'Revenue at risk', render: (r: any) => fmtINR(r.associated_revenue_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const gridCols: Column<any>[] = [
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity },
    { key: 'frequency_bucket', header: 'Frequency bucket', render: (r: any) => r.frequency_bucket },
    { key: 'pain_count', header: 'Pain count', render: (r: any) => r.pain_count },
    { key: 'total_revenue_rupees', header: 'Revenue at risk', render: (r: any) => fmtINR(r.total_revenue_rupees) },
  ];

  const hospitalCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'pain_count', header: 'Total pains', render: (r: any) => r.pain_count },
    { key: 'open_count', header: 'Open / in-prog', render: (r: any) => r.open_count },
    { key: 'total_revenue_rupees', header: 'Revenue at risk', render: (r: any) => fmtINR(r.total_revenue_rupees) },
    { key: 'avg_frequency', header: 'Avg freq', render: (r: any) => r.avg_frequency },
  ];

  const kindCols: Column<any>[] = [
    { key: 'pain_kind', header: 'Kind', render: (r: any) => r.pain_kind },
    { key: 'pain_count', header: 'Total', render: (r: any) => r.pain_count },
    { key: 'open_count', header: 'Open / in-prog', render: (r: any) => r.open_count },
    { key: 'fixed_count', header: 'Fixed', render: (r: any) => r.fixed_count },
    { key: 'total_revenue_rupees', header: 'Revenue at risk', render: (r: any) => fmtINR(r.total_revenue_rupees) },
  ];

  const velocityCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => fmtMonth(r.month_start) },
    { key: 'actions_logged', header: 'Actions', render: (r: any) => r.actions_logged },
    { key: 'positive_outcomes', header: 'Positive outcomes', render: (r: any) => r.positive_outcomes },
    { key: 'pain_points_fixed', header: 'Pains fixed', render: (r: any) => r.pain_points_fixed },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer Pain Points Heatmap</h1>
        <p className="text-sm text-gray-600">
          Pain point signatures & fix actions across hospitals — frequency &gt; severity &gt; revenue at risk &gt; kill priority.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top kill priority (open & in-progress)</h2>
        <DataTable
          rows={killPriority}
          columns={killCols}
          emptyMessage="No active pain points"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Severity × frequency grid</h2>
        <DataTable
          rows={grid}
          columns={gridCols}
          emptyMessage="No grid data"
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top hospitals by pain</h2>
        <DataTable
          rows={topHospitals}
          columns={hospitalCols}
          emptyMessage="No hospitals"
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pain kind breakdown</h2>
        <DataTable
          rows={kindBreakdown}
          columns={kindCols}
          emptyMessage="No breakdown"
          rowKey={(r: any, i: number) => String(r.pain_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly fix velocity</h2>
        <DataTable
          rows={velocity}
          columns={velocityCols}
          emptyMessage="No velocity data"
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All pain points</h2>
        <DataTable
          rows={painPoints}
          columns={painCols}
          emptyMessage="No pain points logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Fix actions log</h2>
        <DataTable
          rows={fixActions}
          columns={actionCols}
          emptyMessage="No fix actions yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
