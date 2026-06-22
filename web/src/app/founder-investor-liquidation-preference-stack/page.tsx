import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorLiquidationPreferenceStackPage() {
  const sb = await getSupabaseServerClient();

  const [stacksRes, seniorityRes, actionsRes] = await Promise.all([
    sb.rpc('list_liquidation_stacks_r1937'),
    sb.rpc('liquidation_stack_by_seniority_r1937'),
    sb.rpc('recent_liquidation_stack_actions_r1937', { p_limit: 25 }),
  ]);

  const stacks: any[] = Array.isArray(stacksRes.data) ? stacksRes.data : [];
  const seniority: any[] = Array.isArray(seniorityRes.data) ? seniorityRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const stackCols: Column<any>[] = [
    { key: 'round_label', header: 'Round', render: (r: any) => String(r.round_label ?? '') },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'seniority', header: 'Seniority', render: (r: any) => String(r.seniority ?? '') },
    { key: 'preference_multiplier', header: 'Multiplier', render: (r: any) => `${Number(r.preference_multiplier ?? 1).toFixed(2)}x` },
    { key: 'preference_type', header: 'Type', render: (r: any) => String(r.preference_type ?? '').replace(/_/g, ' ') },
    { key: 'invested_amount_rupees', header: 'Invested (rupees)', render: (r: any) => Number(r.invested_amount_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleDateString() : '' },
  ];

  const seniorityCols: Column<any>[] = [
    { key: 'seniority', header: 'Seniority tier', render: (r: any) => String(r.seniority ?? '') },
    { key: 'stack_count', header: 'Active stacks', render: (r: any) => String(r.stack_count ?? 0) },
    { key: 'total_invested_rupees', header: 'Total invested (rupees)', render: (r: any) => Number(r.total_invested_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'avg_multiplier', header: 'Avg multiplier', render: (r: any) => `${Number(r.avg_multiplier ?? 0).toFixed(2)}x` },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '').replace(/_/g, ' ') },
    { key: 'stack_id', header: 'Stack', render: (r: any) => String(r.stack_id ?? '').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  const totalActive = stacks.filter((s) => s.status === 'active').length;
  const totalInvested = stacks.reduce((acc, s) => acc + Number(s.invested_amount_rupees ?? 0), 0);

  return (
    <div className="mx-auto max-w-7xl p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Investor liquidation preference stack</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track preference multipliers, seniority ordering, and exercise actions across the cap-table waterfall.
          Active stacks: {totalActive}. Total invested: {totalInvested.toLocaleString('en-IN')} rupees.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-3">Preference stack</h2>
        <DataTable rows={stacks} columns={stackCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">By seniority tier (active only)</h2>
        <DataTable rows={seniority} columns={seniorityCols} rowKey={(r: any, i: number) => String(r.seniority ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Recent stack actions</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
