import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function CustomerMonthlyBusinessReviewTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [
    mbrsRes,
    followupsRes,
    overdueRes,
    summaryRes,
    trendRes,
    topHospitalsRes,
    funnelRes,
  ] = await Promise.all([
    supabase.rpc('list_mbrs_r2469'),
    supabase.rpc('list_action_followups_r2469'),
    supabase.rpc('overdue_actions_r2469'),
    supabase.rpc('effectiveness_summary_r2469'),
    supabase.rpc('monthly_held_trend_r2469'),
    supabase.rpc('top_hospitals_by_effectiveness_r2469'),
    supabase.rpc('status_funnel_r2469'),
  ]);

  const mbrs = (mbrsRes.data ?? []) as any[];
  const followups = (followupsRes.data ?? []) as any[];
  const overdue = (overdueRes.data ?? []) as any[];
  const summary = (summaryRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const topHospitals = (topHospitalsRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];

  const mbrCols: Column<any>[] = [
    { key: 'mbr_month', header: 'Month', render: (r: any) => r.mbr_month },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'held_on', header: 'Held On', render: (r: any) => r.held_on ? new Date(r.held_on).toLocaleString() : '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'mbr_effectiveness_score', header: 'Score', render: (r: any) => `${r.mbr_effectiveness_score}/100` },
    { key: 'action_items_count', header: 'Actions', render: (r: any) => r.action_items_count },
    { key: 'follow_up_count', header: 'Follow-ups', render: (r: any) => r.follow_up_count },
    { key: 'founder_attended', header: 'Founder', render: (r: any) => r.founder_attended ? 'Yes' : 'No' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const followupCols: Column<any>[] = [
    { key: 'mbr_month', header: 'MBR Month', render: (r: any) => r.mbr_month ?? '—' },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'action_text', header: 'Action', render: (r: any) => r.action_text },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'due_at', header: 'Due', render: (r: any) => r.due_at ? new Date(r.due_at).toLocaleDateString() : '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'closed_at', header: 'Closed', render: (r: any) => r.closed_at ? new Date(r.closed_at).toLocaleDateString() : '—' },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'action_text', header: 'Action', render: (r: any) => r.action_text },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'due_at', header: 'Due', render: (r: any) => r.due_at ? new Date(r.due_at).toLocaleDateString() : '—' },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => r.days_overdue },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'total_mbrs', header: 'Total', render: (r: any) => r.total_mbrs },
    { key: 'held_mbrs', header: 'Held', render: (r: any) => r.held_mbrs },
    { key: 'avg_effectiveness', header: 'Avg Score', render: (r: any) => r.avg_effectiveness ?? '—' },
    { key: 'avg_action_items', header: 'Avg Actions', render: (r: any) => r.avg_action_items ?? '—' },
    { key: 'avg_follow_ups', header: 'Avg Follow-ups', render: (r: any) => r.avg_follow_ups ?? '—' },
    { key: 'founder_attended_pct', header: 'Founder Att %', render: (r: any) => r.founder_attended_pct ?? '—' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'mbr_month', header: 'Month', render: (r: any) => r.mbr_month },
    { key: 'held_count', header: 'Held', render: (r: any) => r.held_count },
    { key: 'avg_effectiveness', header: 'Avg Score', render: (r: any) => r.avg_effectiveness ?? '—' },
    { key: 'total_action_items', header: 'Total Actions', render: (r: any) => r.total_action_items },
  ];

  const topCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'mbr_count', header: 'MBR Count', render: (r: any) => r.mbr_count },
    { key: 'avg_effectiveness', header: 'Avg Score', render: (r: any) => r.avg_effectiveness ?? '—' },
    { key: 'total_action_items', header: 'Total Actions', render: (r: any) => r.total_action_items },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'mbr_count', header: 'Count', render: (r: any) => r.mbr_count },
    { key: 'pct', header: 'Percent', render: (r: any) => `${r.pct ?? 0}%` },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer Monthly Business Review Tracker</h1>
        <p className="text-sm text-gray-600">
          Hospital & MBR meetings > KPIs reviewed > action items & follow-ups > MBR effectiveness score.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Effectiveness Summary</h2>
        <DataTable
          rows={summary}
          columns={summaryCols}
          emptyMessage="No summary data yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status Funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No MBRs tracked."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Held Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Hospitals by Effectiveness</h2>
        <DataTable
          rows={topHospitals}
          columns={topCols}
          emptyMessage="No hospitals tracked yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Overdue Action Follow-ups</h2>
        <DataTable
          rows={overdue}
          columns={overdueCols}
          emptyMessage="No overdue actions."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All MBRs</h2>
        <DataTable
          rows={mbrs}
          columns={mbrCols}
          emptyMessage="No MBRs scheduled yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Action Follow-ups</h2>
        <DataTable
          rows={followups}
          columns={followupCols}
          emptyMessage="No follow-ups recorded."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
