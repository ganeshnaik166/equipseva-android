import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    utilizationRes,
    actionsRes,
    idleFocusRes,
    shiftBreakdownRes,
    topUpsellRes,
    weeklyTrendRes,
    actionFunnelRes,
  ] = await Promise.all([
    supabase.rpc('list_utilization_r2499'),
    supabase.rpc('list_upsell_actions_r2499'),
    supabase.rpc('top_idle_focus_r2499'),
    supabase.rpc('shift_breakdown_r2499'),
    supabase.rpc('top_upsell_opportunities_r2499'),
    supabase.rpc('weekly_utilization_trend_r2499'),
    supabase.rpc('action_status_funnel_r2499'),
  ]);

  const utilization = utilizationRes.data ?? [];
  const actions = actionsRes.data ?? [];
  const idleFocus = idleFocusRes.data ?? [];
  const shiftBreakdown = shiftBreakdownRes.data ?? [];
  const topUpsell = topUpsellRes.data ?? [];
  const weeklyTrend = weeklyTrendRes.data ?? [];
  const actionFunnel = actionFunnelRes.data ?? [];

  const fmtRupees = (n: number) =>
    n == null ? '—' : `₹${Number(n).toLocaleString('en-IN')}`;
  const fmtPct = (n: number) =>
    n == null ? '—' : `${Number(n).toFixed(1)}%`;

  const utilizationCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'shift_slot', header: 'Shift', render: (r: any) => r.shift_slot },
    { key: 'hours_used', header: 'Hours used', render: (r: any) => Number(r.hours_used).toFixed(1) },
    { key: 'hours_idle', header: 'Hours idle', render: (r: any) => Number(r.hours_idle).toFixed(1) },
    { key: 'utilization_pct', header: 'Utilization', render: (r: any) => fmtPct(r.utilization_pct) },
    { key: 'revenue_rupees', header: 'Revenue', render: (r: any) => fmtRupees(r.revenue_rupees) },
    { key: 'idle_revenue_loss_rupees', header: 'Idle loss', render: (r: any) => fmtRupees(r.idle_revenue_loss_rupees) },
    { key: 'upsell_opportunity_rupees', header: 'Upsell opp', render: (r: any) => fmtRupees(r.upsell_opportunity_rupees) },
    { key: 'period', header: 'Period', render: (r: any) => `${r.observed_period_start} → ${r.observed_period_end}` },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const actionsCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'expected_revenue_rupees', header: 'Expected ₹', render: (r: any) => fmtRupees(r.expected_revenue_rupees) },
    { key: 'proposed_at', header: 'Proposed', render: (r: any) => new Date(r.proposed_at).toLocaleString() },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const idleFocusCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'shift_slot', header: 'Shift', render: (r: any) => r.shift_slot },
    { key: 'hours_idle', header: 'Hours idle', render: (r: any) => Number(r.hours_idle).toFixed(1) },
    { key: 'idle_revenue_loss_rupees', header: 'Idle loss', render: (r: any) => fmtRupees(r.idle_revenue_loss_rupees) },
    { key: 'utilization_pct', header: 'Utilization', render: (r: any) => fmtPct(r.utilization_pct) },
  ];

  const shiftCols: Column<any>[] = [
    { key: 'shift_slot', header: 'Shift', render: (r: any) => r.shift_slot },
    { key: 'rows_count', header: 'Rows', render: (r: any) => r.rows_count },
    { key: 'total_hours_used', header: 'Hours used', render: (r: any) => Number(r.total_hours_used).toFixed(1) },
    { key: 'total_hours_idle', header: 'Hours idle', render: (r: any) => Number(r.total_hours_idle).toFixed(1) },
    { key: 'total_revenue_rupees', header: 'Revenue', render: (r: any) => fmtRupees(r.total_revenue_rupees) },
    { key: 'total_idle_loss_rupees', header: 'Idle loss', render: (r: any) => fmtRupees(r.total_idle_loss_rupees) },
    { key: 'avg_utilization_pct', header: 'Avg util', render: (r: any) => fmtPct(r.avg_utilization_pct) },
  ];

  const upsellCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'shift_slot', header: 'Shift', render: (r: any) => r.shift_slot },
    { key: 'upsell_opportunity_rupees', header: 'Upsell opp', render: (r: any) => fmtRupees(r.upsell_opportunity_rupees) },
    { key: 'utilization_pct', header: 'Utilization', render: (r: any) => fmtPct(r.utilization_pct) },
  ];

  const weeklyCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => r.week_start },
    { key: 'rows_count', header: 'Rows', render: (r: any) => r.rows_count },
    { key: 'total_hours_used', header: 'Hours used', render: (r: any) => Number(r.total_hours_used).toFixed(1) },
    { key: 'total_hours_idle', header: 'Hours idle', render: (r: any) => Number(r.total_hours_idle).toFixed(1) },
    { key: 'total_revenue_rupees', header: 'Revenue', render: (r: any) => fmtRupees(r.total_revenue_rupees) },
    { key: 'avg_utilization_pct', header: 'Avg util', render: (r: any) => fmtPct(r.avg_utilization_pct) },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'rows_count', header: 'Actions', render: (r: any) => r.rows_count },
    { key: 'total_expected_revenue_rupees', header: 'Expected ₹', render: (r: any) => fmtRupees(r.total_expected_revenue_rupees) },
  ];

  return (
    <main style={{ padding: '1.5rem', display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
      <header>
        <h1 style={{ fontSize: '1.5rem', fontWeight: 600 }}>
          Hospital Chain Equipment Utilization by Shift
        </h1>
        <p style={{ color: '#555' }}>
          Chain & equipment & shift slot → hours used vs idle & revenue vs idle loss & upsell pipeline.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem' }}>Shift breakdown</h2>
        <DataTable
          rows={shiftBreakdown}
          columns={shiftCols}
          emptyMessage="No shift data yet."
          rowKey={(r: any, i: number) => String(r.shift_slot ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem' }}>Top idle focus (biggest loss first)</h2>
        <DataTable
          rows={idleFocus}
          columns={idleFocusCols}
          emptyMessage="No idle rows yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem' }}>Top upsell opportunities</h2>
        <DataTable
          rows={topUpsell}
          columns={upsellCols}
          emptyMessage="No upsell rows yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem' }}>Weekly utilization trend</h2>
        <DataTable
          rows={weeklyTrend}
          columns={weeklyCols}
          emptyMessage="No trend data yet."
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem' }}>Action status funnel</h2>
        <DataTable
          rows={actionFunnel}
          columns={funnelCols}
          emptyMessage="No actions yet."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem' }}>All utilization rows</h2>
        <DataTable
          rows={utilization}
          columns={utilizationCols}
          emptyMessage="No utilization rows yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem' }}>Upsell actions</h2>
        <DataTable
          rows={actions}
          columns={actionsCols}
          emptyMessage="No actions yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
