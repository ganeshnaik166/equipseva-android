import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerJobDeclineTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [declinesRes, patternsRes, topRes, distRes, escRes] = await Promise.all([
    sb.rpc('list_declines_r1748', { p_limit: 100 }),
    sb.rpc('list_patterns_r1748', { p_limit: 100 }),
    sb.rpc('top_decliners_r1748', { p_limit: 20 }),
    sb.rpc('decline_reason_distribution_r1748'),
    sb.rpc('recent_escalations_r1748', { p_limit: 50 }),
  ]);

  const declines: any[] = Array.isArray(declinesRes.data) ? declinesRes.data : [];
  const patterns: any[] = Array.isArray(patternsRes.data) ? patternsRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const dist: any[] = Array.isArray(distRes.data) ? distRes.data : [];
  const esc: any[] = Array.isArray(escRes.data) ? escRes.data : [];

  const totalDeclines = declines.length;
  const totalFollowUp = declines.filter((d) => d.follow_up_required).length;
  const totalEscalated = esc.length;

  const declineCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'decline_reason', header: 'Reason', render: (r: any) => r.decline_reason ?? '—' },
    { key: 'declined_at', header: 'Declined', render: (r: any) => r.declined_at ? new Date(r.declined_at).toLocaleString() : '—' },
    { key: 'would_take_if', header: 'Would Take If', render: (r: any) => r.would_take_if ?? '—' },
    { key: 'follow_up_required', header: 'Follow Up', render: (r: any) => r.follow_up_required ? 'Yes' : 'No' },
    { key: 'escalated_to_email', header: 'Escalated To', render: (r: any) => r.escalated_to_email ?? '—' },
  ];

  const patternCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'total_declines', header: 'Total', render: (r: any) => String(r.total_declines ?? 0) },
    { key: 'decline_rate_pct', header: 'Rate %', render: (r: any) => String(r.decline_rate_pct ?? 0) },
    { key: 'most_common_reason', header: 'Top Reason', render: (r: any) => r.most_common_reason ?? '—' },
    { key: 'last_decline_at', header: 'Last Decline', render: (r: any) => r.last_decline_at ? new Date(r.last_decline_at).toLocaleString() : '—' },
    { key: 'recomputed_at', header: 'Recomputed', render: (r: any) => r.recomputed_at ? new Date(r.recomputed_at).toLocaleString() : '—' },
  ];

  const topCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'total_declines', header: 'Total Declines', render: (r: any) => String(r.total_declines ?? 0) },
    { key: 'most_common_reason', header: 'Top Reason', render: (r: any) => r.most_common_reason ?? '—' },
    { key: 'last_decline_at', header: 'Last', render: (r: any) => r.last_decline_at ? new Date(r.last_decline_at).toLocaleString() : '—' },
  ];

  const distCols: Column<any>[] = [
    { key: 'decline_reason', header: 'Reason', render: (r: any) => r.decline_reason ?? '—' },
    { key: 'total', header: 'Count', render: (r: any) => String(r.total ?? 0) },
    { key: 'pct', header: 'Pct %', render: (r: any) => String(r.pct ?? 0) },
  ];

  const escCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'decline_reason', header: 'Reason', render: (r: any) => r.decline_reason ?? '—' },
    { key: 'declined_at', header: 'Declined', render: (r: any) => r.declined_at ? new Date(r.declined_at).toLocaleString() : '—' },
    { key: 'escalated_to_email', header: 'Escalated To', render: (r: any) => r.escalated_to_email ?? '—' },
    { key: 'would_take_if', header: 'Would Take If', render: (r: any) => r.would_take_if ?? '—' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Job Decline Tracker</h1>
        <p className="text-sm text-gray-600">Track engineer job-decline patterns by reason taxonomy and follow-up status.</p>
      </header>

      <section className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Total Declines (recent)</div>
          <div className="text-2xl font-semibold">{totalDeclines}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Follow-Up Required</div>
          <div className="text-2xl font-semibold">{totalFollowUp}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Escalated</div>
          <div className="text-2xl font-semibold">{totalEscalated}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Reason Distribution</h2>
        <DataTable rows={dist} columns={distCols} rowKey={(r: any, i: number) => String(r.decline_reason ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Decliners</h2>
        <DataTable rows={top} columns={topCols} rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Decline Patterns</h2>
        <DataTable rows={patterns} columns={patternCols} rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Declines</h2>
        <DataTable rows={declines} columns={declineCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Escalations</h2>
        <DataTable rows={esc} columns={escCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
