import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalChainEquipmentVendorSwitchPressurePage() {
  const supabase = await getSupabaseServerClient();

  const [pressures, actions, atRisk, signalDist, counterSummary, monthlyTrend, ownerLoad] = await Promise.all([
    supabase.rpc('list_switch_pressure_r2583'),
    supabase.rpc('list_counter_actions_r2583'),
    supabase.rpc('top_at_risk_chains_r2583'),
    supabase.rpc('signal_kind_distribution_r2583'),
    supabase.rpc('counter_kind_summary_r2583'),
    supabase.rpc('monthly_pressure_trend_r2583'),
    supabase.rpc('owner_load_r2583'),
  ]);

  const pressureCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'vendor_under_pressure', header: 'Vendor', render: (r: any) => r.vendor_under_pressure },
    { key: 'signal_kind', header: 'Signal', render: (r: any) => r.signal_kind },
    { key: 'signal_strength', header: 'Strength', render: (r: any) => r.signal_strength },
    { key: 'decision_risk_kind', header: 'Risk', render: (r: any) => r.decision_risk_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'action_at', header: 'When', render: (r: any) => r.action_at ? new Date(r.action_at).toLocaleString() : '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const atRiskCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'pressure_count', header: 'Pressures', render: (r: any) => r.pressure_count },
    { key: 'critical_count', header: 'Critical', render: (r: any) => r.critical_count },
    { key: 'high_count', header: 'High', render: (r: any) => r.high_count },
    { key: 'escalated_count', header: 'Escalated', render: (r: any) => r.escalated_count },
  ];

  const signalCols: Column<any>[] = [
    { key: 'signal_kind', header: 'Signal', render: (r: any) => r.signal_kind },
    { key: 'pressure_count', header: 'Count', render: (r: any) => r.pressure_count },
    { key: 'strong_or_confirmed', header: 'Strong / Confirmed', render: (r: any) => r.strong_or_confirmed },
  ];

  const counterCols: Column<any>[] = [
    { key: 'action_kind', header: 'Counter Action', render: (r: any) => r.action_kind },
    { key: 'action_count', header: 'Count', render: (r: any) => r.action_count },
    { key: 'positive_count', header: 'Positive', render: (r: any) => r.positive_count },
    { key: 'pending_count', header: 'Pending', render: (r: any) => r.pending_count },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start ? new Date(r.month_start).toLocaleDateString() : '-' },
    { key: 'pressure_count', header: 'Pressures', render: (r: any) => r.pressure_count },
    { key: 'critical_count', header: 'Critical', render: (r: any) => r.critical_count },
    { key: 'saved_count', header: 'Saved', render: (r: any) => r.saved_count },
    { key: 'lost_count', header: 'Lost', render: (r: any) => r.lost_count },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'pressure_count', header: 'Pressures', render: (r: any) => r.pressure_count },
    { key: 'escalated_count', header: 'Escalated', render: (r: any) => r.escalated_count },
    { key: 'action_count', header: 'Actions', render: (r: any) => r.action_count },
    { key: 'open_actions', header: 'Open Actions', render: (r: any) => r.open_actions },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 32 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Hospital Chain — Equipment Vendor Switch Pressure</h1>
        <p style={{ color: '#555' }}>
          Track which chains are actively shopping alternatives, signal strength & decision risk, and counter-actions
          to keep the account. Escalated => founder owns within 48h.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top At-Risk Chains</h2>
        <DataTable
          rows={atRisk.data ?? []}
          columns={atRiskCols}
          emptyMessage="No at-risk chains"
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Active Pressures</h2>
        <DataTable
          rows={pressures.data ?? []}
          columns={pressureCols}
          emptyMessage="No pressures recorded"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Counter Actions</h2>
        <DataTable
          rows={actions.data ?? []}
          columns={actionCols}
          emptyMessage="No counter actions logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Signal Kind Distribution</h2>
        <DataTable
          rows={signalDist.data ?? []}
          columns={signalCols}
          emptyMessage="No signals"
          rowKey={(r: any, i: number) => String(r.signal_kind ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Counter Kind Summary</h2>
        <DataTable
          rows={counterSummary.data ?? []}
          columns={counterCols}
          emptyMessage="No counter actions"
          rowKey={(r: any, i: number) => String(r.action_kind ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly Pressure Trend</h2>
        <DataTable
          rows={monthlyTrend.data ?? []}
          columns={trendCols}
          emptyMessage="No history"
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Owner Load</h2>
        <DataTable
          rows={ownerLoad.data ?? []}
          columns={ownerCols}
          emptyMessage="No owners"
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </div>
  );
}
