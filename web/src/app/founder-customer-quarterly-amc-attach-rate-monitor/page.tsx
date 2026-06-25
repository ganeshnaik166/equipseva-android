import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderCustomerQuarterlyAmcAttachRateMonitorPage() {
  const supabase = await getSupabaseServerClient();

  const [attachRes, actionsRes, focusRes, distRes, funnelRes, trendRes, loadRes] = await Promise.all([
    supabase.rpc('list_attach_r2668'),
    supabase.rpc('list_improvement_actions_r2668'),
    supabase.rpc('top_below_target_focus_r2668'),
    supabase.rpc('status_distribution_r2668'),
    supabase.rpc('status_funnel_r2668'),
    supabase.rpc('quarterly_attach_trend_r2668'),
    supabase.rpc('owner_load_r2668'),
  ]);

  const attach = (attachRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const focus = (focusRes.data ?? []) as any[];
  const distribution = (distRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const load = (loadRes.data ?? []) as any[];

  const totalAttach = attach.length;
  const belowTarget = attach.filter((r: any) => r.status === 'below_target').length;
  const aboveTarget = attach.filter((r: any) => r.status === 'above_target').length;
  const atTarget = attach.filter((r: any) => r.status === 'at_target').length;
  const dropped = attach.filter((r: any) => r.status === 'dropped').length;
  const openActions = actions.filter((r: any) => r.status === 'open').length;

  const attachColumns: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'equipment_count', header: 'Equipment', render: (r: any) => r.equipment_count },
    { key: 'amc_signed_count', header: 'AMC Signed', render: (r: any) => r.amc_signed_count },
    { key: 'attach_rate_pct', header: 'Attach %', render: (r: any) => `${r.attach_rate_pct}%` },
    { key: 'target_attach_pct', header: 'Target %', render: (r: any) => `${r.target_attach_pct}%` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const actionColumns: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'action_at', header: 'Action At', render: (r: any) => new Date(r.action_at).toLocaleDateString() },
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const focusColumns: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'equipment_count', header: 'Equipment', render: (r: any) => r.equipment_count },
    { key: 'amc_signed_count', header: 'Signed', render: (r: any) => r.amc_signed_count },
    { key: 'attach_rate_pct', header: 'Attach %', render: (r: any) => `${r.attach_rate_pct}%` },
    { key: 'target_attach_pct', header: 'Target %', render: (r: any) => `${r.target_attach_pct}%` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const distributionColumns: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'attach_count', header: 'Attach Records', render: (r: any) => r.attach_count },
  ];

  const funnelColumns: Column<any>[] = [
    { key: 'status', header: 'Action Status', render: (r: any) => r.status },
    { key: 'action_count', header: 'Actions', render: (r: any) => r.action_count },
  ];

  const trendColumns: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'total_records', header: 'Records', render: (r: any) => r.total_records },
    { key: 'total_equipment', header: 'Equipment', render: (r: any) => r.total_equipment },
    { key: 'total_amc_signed', header: 'AMC Signed', render: (r: any) => r.total_amc_signed },
    { key: 'avg_attach_pct', header: 'Avg Attach %', render: (r: any) => `${r.avg_attach_pct}%` },
  ];

  const loadColumns: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'attach_records', header: 'Attach Records', render: (r: any) => r.attach_records },
    { key: 'open_actions', header: 'Open Actions', render: (r: any) => r.open_actions },
    { key: 'avg_attach_pct', header: 'Avg Attach %', render: (r: any) => `${r.avg_attach_pct}%` },
  ];

  return (
    <div className="mx-auto max-w-7xl px-4 py-6 space-y-8">
      <div>
        <h1 className="text-2xl font-bold">Customer Quarterly AMC Attach Rate Monitor</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track AMC attach rate per hospital per quarter and improvement actions taken to lift it.
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500">Total Records</div>
          <div className="text-2xl font-bold">{totalAttach}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500">Below Target</div>
          <div className="text-2xl font-bold">{belowTarget}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500">At Target</div>
          <div className="text-2xl font-bold">{atTarget}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500">Above Target</div>
          <div className="text-2xl font-bold">{aboveTarget}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500">Dropped</div>
          <div className="text-2xl font-bold">{dropped}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500">Open Actions</div>
          <div className="text-2xl font-bold">{openActions}</div>
        </div>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Attach Rate Records</h2>
        <DataTable
          rows={attach}
          columns={attachColumns}
          emptyMessage="No attach records yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Below-Target Focus (status = below_target or dropped)</h2>
        <DataTable
          rows={focus}
          columns={focusColumns}
          emptyMessage="No below-target records."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Improvement Actions Log</h2>
        <DataTable
          rows={actions}
          columns={actionColumns}
          emptyMessage="No improvement actions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <div className="grid md:grid-cols-2 gap-6">
        <section>
          <h2 className="text-lg font-semibold mb-2">Status Distribution</h2>
          <DataTable
            rows={distribution}
            columns={distributionColumns}
            emptyMessage="No data."
            rowKey={(r: any, i: number) => String(r.status ?? i)}
          />
        </section>

        <section>
          <h2 className="text-lg font-semibold mb-2">Action Status Funnel</h2>
          <DataTable
            rows={funnel}
            columns={funnelColumns}
            emptyMessage="No actions."
            rowKey={(r: any, i: number) => String(r.status ?? i)}
          />
        </section>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly Attach Trend</h2>
        <DataTable
          rows={trend}
          columns={trendColumns}
          emptyMessage="No quarter data."
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Owner Load</h2>
        <DataTable
          rows={load}
          columns={loadColumns}
          emptyMessage="No owners."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </div>
  );
}
