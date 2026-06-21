import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

async function rpc(name: string) {
  const sb = await getSupabaseServerClient();
  try {
    const { data, error } = await sb.rpc(name);
    if (error) return [];
    return Array.isArray(data) ? data : (data ? [data] : []);
  } catch {
    return [];
  }
}

export default async function Page() {
  await requireFounder();

  const overviewRows = await rpc('rpc_founder_investor_pipeline_overview');
  const active = await rpc('rpc_founder_investor_pipeline_active');
  const drops = await rpc('rpc_founder_investor_drop_candidates');
  const pushes = await rpc('rpc_founder_investor_push_candidates');
  const history = await rpc('rpc_founder_investor_triage_history');
  const stages = await rpc('rpc_founder_investor_stage_breakdown');
  const logs = await rpc('rpc_founder_investor_action_log_recent');

  const o: any = overviewRows[0] ?? {};

  const kpis: Kpi[] = [
    { label: 'Active', value: String(o.total_active ?? 0) },
    { label: 'Dropped', value: String(o.total_dropped ?? 0) },
    { label: 'Won', value: String(o.total_won ?? 0) },
    { label: 'Lost', value: String(o.total_lost ?? 0) },
    { label: 'High Heat', value: String(o.high_heat_count ?? 0) },
    { label: 'Low Fit', value: String(o.low_fit_count ?? 0) },
    { label: 'Diligence', value: String(o.diligence_count ?? 0) },
    { label: 'Term Sheet', value: String(o.term_sheet_count ?? 0) },
    { label: 'Avg Fit', value: String(o.avg_fit_score ?? '—') },
    { label: 'Avg Heat', value: String(o.avg_heat_score ?? '—') },
    { label: 'Pipeline (L)', value: String(o.pipeline_value_lakh ?? 0) },
    { label: 'Drop Candidates', value: String(drops.length) },
    { label: 'Push Candidates', value: String(pushes.length) },
    { label: 'Stages Active', value: String(stages.length) },
    { label: 'Sessions Logged', value: String(history.length) },
    { label: 'Recent Actions', value: String(logs.length) },
  ];

  const activeCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '—' },
    { key: 'firm', header: 'Firm', render: (r: any) => r.firm ?? '—' },
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? '—' },
    { key: 'fit_score', header: 'Fit', render: (r: any) => String(r.fit_score ?? '—') },
    { key: 'heat_score', header: 'Heat', render: (r: any) => String(r.heat_score ?? '—') },
    { key: 'ticket_size_lakh', header: 'Ticket (L)', render: (r: any) => String(r.ticket_size_lakh ?? '—') },
    { key: 'days_since_touch', header: 'Days Since Touch', render: (r: any) => String(r.days_since_touch ?? '—') },
    { key: 'next_action', header: 'Next Action', render: (r: any) => r.next_action ?? '—' },
  ];

  const dropCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '—' },
    { key: 'firm', header: 'Firm', render: (r: any) => r.firm ?? '—' },
    { key: 'fit_score', header: 'Fit', render: (r: any) => String(r.fit_score ?? '—') },
    { key: 'heat_score', header: 'Heat', render: (r: any) => String(r.heat_score ?? '—') },
    { key: 'days_since_touch', header: 'Days', render: (r: any) => String(r.days_since_touch ?? '—') },
    { key: 'drop_reason', header: 'Reason', render: (r: any) => r.drop_reason ?? '—' },
  ];

  const pushCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '—' },
    { key: 'firm', header: 'Firm', render: (r: any) => r.firm ?? '—' },
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? '—' },
    { key: 'fit_score', header: 'Fit', render: (r: any) => String(r.fit_score ?? '—') },
    { key: 'heat_score', header: 'Heat', render: (r: any) => String(r.heat_score ?? '—') },
    { key: 'ticket_size_lakh', header: 'Ticket (L)', render: (r: any) => String(r.ticket_size_lakh ?? '—') },
    { key: 'next_action', header: 'Next Action', render: (r: any) => r.next_action ?? '—' },
  ];

  const stageCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? '—' },
    { key: 'cnt', header: 'Count', render: (r: any) => String(r.cnt ?? 0) },
    { key: 'avg_fit', header: 'Avg Fit', render: (r: any) => String(r.avg_fit ?? '—') },
    { key: 'avg_heat', header: 'Avg Heat', render: (r: any) => String(r.avg_heat ?? '—') },
    { key: 'total_lakh', header: 'Total (L)', render: (r: any) => String(r.total_lakh ?? 0) },
  ];

  const logCols: Column<any>[] = [
    { key: 'ts', header: 'When', render: (r: any) => r.ts ? new Date(r.ts).toLocaleString() : '—' },
    { key: 'actor_email', header: 'Actor', render: (r: any) => r.actor_email ?? '—' },
    { key: 'op_name', header: 'Op', render: (r: any) => r.op_name ?? '—' },
    { key: 'after_value', header: 'Payload', render: (r: any) => r.after_value ? JSON.stringify(r.after_value) : '—' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Investor Pipeline Triage</h1>
        <p className="text-sm text-gray-600">Every 7 days: drop low-fit, push high-heat, add new prospects. Founder-only.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-3">
        {kpis.map((k, i) => (
          <div key={i} className="rounded-lg border p-3">
            <div className="text-xs uppercase text-gray-500">{k.label}</div>
            <div className="text-lg font-semibold">{k.value}</div>
          </div>
        ))}
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Active Pipeline (top 100)</h2>
        <DataTable columns={activeCols} rows={active as any[]} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Drop Candidates</h2>
        <DataTable columns={dropCols} rows={drops as any[]} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Push Candidates</h2>
        <DataTable columns={pushCols} rows={pushes as any[]} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Stage Breakdown</h2>
        <DataTable columns={stageCols} rows={stages as any[]} rowKey={(r: any) => r.stage} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Recent Triage Actions</h2>
        <DataTable columns={logCols} rows={logs as any[]} rowKey={(r: any) => String(r.id)} />
      </section>
    </main>
  );
}
