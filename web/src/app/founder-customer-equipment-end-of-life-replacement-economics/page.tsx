import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [economics, decisions, topPayback, decisionDist, statusFunnel, monthlyTrend, ownerLoad] = await Promise.all([
    supabase.rpc('list_economics_r2632'),
    supabase.rpc('list_decisions_r2632'),
    supabase.rpc('top_payback_focus_r2632'),
    supabase.rpc('decision_kind_distribution_r2632'),
    supabase.rpc('status_funnel_r2632'),
    supabase.rpc('monthly_decision_trend_r2632'),
    supabase.rpc('owner_load_r2632'),
  ]);

  const economicsRows: any[] = economics.data ?? [];
  const decisionsRows: any[] = decisions.data ?? [];
  const topPaybackRows: any[] = topPayback.data ?? [];
  const decisionDistRows: any[] = decisionDist.data ?? [];
  const statusFunnelRows: any[] = statusFunnel.data ?? [];
  const monthlyTrendRows: any[] = monthlyTrend.data ?? [];
  const ownerLoadRows: any[] = ownerLoad.data ?? [];

  const economicsCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'age_years', header: 'Age (yrs)', render: (r: any) => String(r.age_years) },
    { key: 'maintenance_ttm_rupees', header: 'TTM Maint (Rs)', render: (r: any) => String(r.maintenance_ttm_rupees) },
    { key: 'replacement_cost_rupees', header: 'Replace Cost (Rs)', render: (r: any) => String(r.replacement_cost_rupees) },
    { key: 'payback_months', header: 'Payback (mo)', render: (r: any) => String(r.payback_months) },
    { key: 'decision_kind', header: 'Decision', render: (r: any) => r.decision_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const decisionsCols: Column<any>[] = [
    { key: 'decided_at', header: 'Decided At', render: (r: any) => String(r.decided_at).slice(0, 10) },
    { key: 'decision_kind', header: 'Decision', render: (r: any) => r.decision_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topPaybackCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'payback_months', header: 'Payback (mo)', render: (r: any) => String(r.payback_months) },
    { key: 'maintenance_ttm_rupees', header: 'TTM Maint (Rs)', render: (r: any) => String(r.maintenance_ttm_rupees) },
    { key: 'replacement_cost_rupees', header: 'Replace Cost (Rs)', render: (r: any) => String(r.replacement_cost_rupees) },
    { key: 'decision_kind', header: 'Decision', render: (r: any) => r.decision_kind },
  ];

  const decisionDistCols: Column<any>[] = [
    { key: 'decision_kind', header: 'Decision Kind', render: (r: any) => r.decision_kind },
    { key: 'cnt', header: 'Count', render: (r: any) => String(r.cnt) },
  ];

  const statusFunnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'cnt', header: 'Count', render: (r: any) => String(r.cnt) },
  ];

  const monthlyTrendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'cnt', header: 'Decisions', render: (r: any) => String(r.cnt) },
  ];

  const ownerLoadCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'cnt', header: 'Load', render: (r: any) => String(r.cnt) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Customer Equipment End-of-Life Replacement Economics</h1>
        <p className="text-sm text-gray-600 mt-1">Track aging assets, maintenance vs replacement payback, and decision pipeline.</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-3">Economics Register</h2>
        <DataTable
          rows={economicsRows}
          columns={economicsCols}
          emptyMessage="No economics records yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Top Payback Focus (lowest months first)</h2>
        <DataTable
          rows={topPaybackRows}
          columns={topPaybackCols}
          emptyMessage="No payback data"
          rowKey={(r: any, i: number) => String(r.equipment_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Decision Kind Distribution</h2>
        <DataTable
          rows={decisionDistRows}
          columns={decisionDistCols}
          emptyMessage="No decisions logged"
          rowKey={(r: any, i: number) => String(r.decision_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Status Funnel</h2>
        <DataTable
          rows={statusFunnelRows}
          columns={statusFunnelCols}
          emptyMessage="No status rows"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Monthly Decision Trend</h2>
        <DataTable
          rows={monthlyTrendRows}
          columns={monthlyTrendCols}
          emptyMessage="No monthly trend data"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Owner Load</h2>
        <DataTable
          rows={ownerLoadRows}
          columns={ownerLoadCols}
          emptyMessage="No owners assigned"
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Decision Log</h2>
        <DataTable
          rows={decisionsRows}
          columns={decisionsCols}
          emptyMessage="No decision log entries"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
