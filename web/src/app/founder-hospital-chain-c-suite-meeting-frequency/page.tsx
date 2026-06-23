import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalChainCSuiteMeetingFrequencyPage() {
  const supabase = await getSupabaseServerClient();

  const [cadenceRes, outcomesRes, laggingRes, roleRes, influenceRes, trendRes, ownerRes] = await Promise.all([
    supabase.rpc('list_meeting_cadence_r2595'),
    supabase.rpc('list_meeting_outcomes_r2595'),
    supabase.rpc('lagging_focus_r2595'),
    supabase.rpc('role_distribution_r2595'),
    supabase.rpc('deal_influence_summary_r2595'),
    supabase.rpc('monthly_meeting_trend_r2595'),
    supabase.rpc('owner_load_r2595'),
  ]);

  const cadence = (cadenceRes.data ?? []) as any[];
  const outcomes = (outcomesRes.data ?? []) as any[];
  const lagging = (laggingRes.data ?? []) as any[];
  const roles = (roleRes.data ?? []) as any[];
  const influence = (influenceRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const owners = (ownerRes.data ?? []) as any[];

  const fmtDate = (v: any) => (v ? new Date(v).toLocaleDateString() : '-');
  const fmtMonth = (v: any) => (v ? new Date(v).toLocaleDateString(undefined, { year: 'numeric', month: 'short' }) : '-');

  const cadenceCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'c_suite_role', header: 'Role', render: (r: any) => r.c_suite_role },
    { key: 'planned_cadence_days', header: 'Cadence (days)', render: (r: any) => r.planned_cadence_days },
    { key: 'last_meeting_at', header: 'Last', render: (r: any) => fmtDate(r.last_meeting_at) },
    { key: 'next_meeting_at', header: 'Next', render: (r: any) => fmtDate(r.next_meeting_at) },
    { key: 'meetings_held_count', header: 'Held', render: (r: any) => r.meetings_held_count },
    { key: 'actions_count', header: 'Actions', render: (r: any) => r.actions_count },
    { key: 'deal_influence_kind', header: 'Deal Influence', render: (r: any) => r.deal_influence_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const outcomesCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name ?? '-' },
    { key: 'c_suite_role', header: 'Role', render: (r: any) => r.c_suite_role ?? '-' },
    { key: 'meeting_at', header: 'Meeting', render: (r: any) => fmtDate(r.meeting_at) },
    { key: 'outcome_kind', header: 'Outcome', render: (r: any) => r.outcome_kind },
    { key: 'summary_md', header: 'Summary', render: (r: any) => r.summary_md ?? '-' },
    { key: 'follow_up_required', header: 'Follow-up?', render: (r: any) => (r.follow_up_required ? 'Yes' : 'No') },
    { key: 'follow_up_at', header: 'Follow-up at', render: (r: any) => fmtDate(r.follow_up_at) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const laggingCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'c_suite_role', header: 'Role', render: (r: any) => r.c_suite_role },
    { key: 'days_since_last', header: 'Days since last', render: (r: any) => r.days_since_last },
    { key: 'planned_cadence_days', header: 'Planned (days)', render: (r: any) => r.planned_cadence_days },
    { key: 'overdue_days', header: 'Overdue (days)', render: (r: any) => r.overdue_days },
    { key: 'deal_influence_kind', header: 'Deal Influence', render: (r: any) => r.deal_influence_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const roleCols: Column<any>[] = [
    { key: 'c_suite_role', header: 'Role', render: (r: any) => r.c_suite_role },
    { key: 'cadence_count', header: 'Cadences', render: (r: any) => r.cadence_count },
    { key: 'total_meetings_held', header: 'Meetings held', render: (r: any) => r.total_meetings_held },
    { key: 'total_actions', header: 'Actions', render: (r: any) => r.total_actions },
    { key: 'avg_planned_cadence_days', header: 'Avg cadence (days)', render: (r: any) => r.avg_planned_cadence_days },
  ];

  const influenceCols: Column<any>[] = [
    { key: 'deal_influence_kind', header: 'Deal Influence', render: (r: any) => r.deal_influence_kind },
    { key: 'chain_count', header: 'Chains', render: (r: any) => r.chain_count },
    { key: 'total_meetings', header: 'Meetings', render: (r: any) => r.total_meetings },
    { key: 'total_actions', header: 'Actions', render: (r: any) => r.total_actions },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => fmtMonth(r.month_start) },
    { key: 'meeting_count', header: 'Meetings', render: (r: any) => r.meeting_count },
    { key: 'positive_count', header: 'Positive', render: (r: any) => r.positive_count },
    { key: 'concerned_count', header: 'Concerned', render: (r: any) => r.concerned_count },
    { key: 'deal_advance_count', header: 'Deal advance', render: (r: any) => r.deal_advance_count },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'cadence_count', header: 'Cadences', render: (r: any) => r.cadence_count },
    { key: 'open_followups', header: 'Open follow-ups', render: (r: any) => r.open_followups },
    { key: 'total_meetings_held', header: 'Meetings held', render: (r: any) => r.total_meetings_held },
  ];

  return (
    <main className="mx-auto max-w-7xl px-6 py-10 space-y-10">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Hospital Chain C-Suite Meeting Frequency</h1>
        <p className="text-sm text-gray-600">
          Track founder-level cadence with chain C-suite & owners, meeting outcomes, deal influence, and lagging follow-ups.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Cadence by chain & role</h2>
        <DataTable
          rows={cadence}
          columns={cadenceCols}
          emptyMessage="No cadence rows yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Lagging focus (overdue vs planned cadence)</h2>
        <DataTable
          rows={lagging}
          columns={laggingCols}
          emptyMessage="No lagging cadences."
          rowKey={(r: any, i: number) => String(`${r.chain_name}-${r.c_suite_role}-${i}`)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Meeting outcomes</h2>
        <DataTable
          rows={outcomes}
          columns={outcomesCols}
          emptyMessage="No outcomes logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-8">
        <div className="space-y-3">
          <h2 className="text-lg font-medium">Role distribution</h2>
          <DataTable
            rows={roles}
            columns={roleCols}
            emptyMessage="No role data."
            rowKey={(r: any, i: number) => String(r.c_suite_role ?? i)}
          />
        </div>
        <div className="space-y-3">
          <h2 className="text-lg font-medium">Deal influence summary</h2>
          <DataTable
            rows={influence}
            columns={influenceCols}
            emptyMessage="No influence data."
            rowKey={(r: any, i: number) => String(r.deal_influence_kind ?? i)}
          />
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Monthly meeting trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Owner load</h2>
        <DataTable
          rows={owners}
          columns={ownerCols}
          emptyMessage="No owner data."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </main>
  );
}
