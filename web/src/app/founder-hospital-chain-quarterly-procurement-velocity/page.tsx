import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalChainQuarterlyProcurementVelocityPage() {
  const supabase = await getSupabaseServerClient();

  const [
    velocityRes,
    actionsRes,
    slowRes,
    kindDistRes,
    statusFunnelRes,
    quarterlyTrendRes,
    ownerLoadRes,
  ] = await Promise.all([
    supabase.rpc('list_velocity_r2655'),
    supabase.rpc('list_acceleration_actions_r2655'),
    supabase.rpc('top_slow_focus_r2655'),
    supabase.rpc('velocity_kind_distribution_r2655'),
    supabase.rpc('status_funnel_r2655'),
    supabase.rpc('quarterly_velocity_trend_r2655'),
    supabase.rpc('owner_load_r2655'),
  ]);

  const velocity = (velocityRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const slow = (slowRes.data ?? []) as any[];
  const kindDist = (kindDistRes.data ?? []) as any[];
  const statusFunnel = (statusFunnelRes.data ?? []) as any[];
  const quarterlyTrend = (quarterlyTrendRes.data ?? []) as any[];
  const ownerLoad = (ownerLoadRes.data ?? []) as any[];

  const velocityCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'rfp_to_po_days', header: 'RFP => PO (days)', render: (r: any) => r.rfp_to_po_days },
    { key: 'po_to_payment_days', header: 'PO => Pay (days)', render: (r: any) => r.po_to_payment_days },
    { key: 'total_cycle_days', header: 'Total cycle', render: (r: any) => r.total_cycle_days },
    { key: 'velocity_kind', header: 'Velocity', render: (r: any) => r.velocity_kind },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const actionsCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'action_at', header: 'When', render: (r: any) => new Date(r.action_at).toLocaleString() },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const slowCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'total_cycle_days', header: 'Total cycle', render: (r: any) => r.total_cycle_days },
    { key: 'velocity_kind', header: 'Velocity', render: (r: any) => r.velocity_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const kindDistCols: Column<any>[] = [
    { key: 'velocity_kind', header: 'Velocity kind', render: (r: any) => r.velocity_kind },
    { key: 'chain_count', header: 'Chains', render: (r: any) => r.chain_count },
    { key: 'avg_cycle_days', header: 'Avg cycle (days)', render: (r: any) => r.avg_cycle_days },
  ];

  const statusFunnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'chain_count', header: 'Chains', render: (r: any) => r.chain_count },
  ];

  const trendCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'chain_count', header: 'Chains', render: (r: any) => r.chain_count },
    { key: 'avg_rfp_to_po', header: 'Avg RFP => PO', render: (r: any) => r.avg_rfp_to_po },
    { key: 'avg_po_to_payment', header: 'Avg PO => Pay', render: (r: any) => r.avg_po_to_payment },
    { key: 'avg_total_cycle', header: 'Avg total', render: (r: any) => r.avg_total_cycle },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'chain_count', header: 'Chains', render: (r: any) => r.chain_count },
    { key: 'slow_or_blocked', header: 'Slow & blocked', render: (r: any) => r.slow_or_blocked },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Procurement Velocity</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track RFP =&gt; PO =&gt; Payment cycle time across chain customers and the acceleration actions taken to unblock slow chains.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain velocity</h2>
        <DataTable
          rows={velocity}
          columns={velocityCols}
          emptyMessage="No velocity records yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top slow & blocked focus</h2>
        <DataTable
          rows={slow}
          columns={slowCols}
          emptyMessage="No slow or blocked chains."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Acceleration actions</h2>
        <DataTable
          rows={actions}
          columns={actionsCols}
          emptyMessage="No acceleration actions logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Velocity kind distribution</h2>
        <DataTable
          rows={kindDist}
          columns={kindDistCols}
          emptyMessage="No data."
          rowKey={(r: any, i: number) => String(r.velocity_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status funnel</h2>
        <DataTable
          rows={statusFunnel}
          columns={statusFunnelCols}
          emptyMessage="No data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly velocity trend</h2>
        <DataTable
          rows={quarterlyTrend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Owner load</h2>
        <DataTable
          rows={ownerLoad}
          columns={ownerCols}
          emptyMessage="No owner data."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </div>
  );
}
