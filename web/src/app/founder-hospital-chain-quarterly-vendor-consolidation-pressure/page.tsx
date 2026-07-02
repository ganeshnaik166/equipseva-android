import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [pressureRes, actionsRes, focusRes, kindRes, funnelRes, trendRes, ownerRes] = await Promise.all([
    supabase.rpc('list_pressure_r2647'),
    supabase.rpc('list_counter_actions_r2647'),
    supabase.rpc('top_threat_focus_r2647'),
    supabase.rpc('our_threat_kind_distribution_r2647'),
    supabase.rpc('status_funnel_r2647'),
    supabase.rpc('quarterly_pressure_trend_r2647'),
    supabase.rpc('owner_load_r2647'),
  ]);

  const pressure = (pressureRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const focus = (focusRes.data ?? []) as any[];
  const kind = (kindRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const owners = (ownerRes.data ?? []) as any[];

  const totalPressure = pressure.length;
  const escalatedCount = pressure.filter((p) => p.status === 'escalated').length;
  const totalGap = pressure.reduce((sum, p) => sum + (Number(p.vendor_count_today ?? 0) - Number(p.target_vendor_count ?? 0)), 0);
  const totalActions = actions.length;
  const openActions = actions.filter((a) => a.status === 'open').length;

  const pressureColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'vendor_count_today', header: 'Vendors Today', render: (r: any) => r.vendor_count_today },
    { key: 'target_vendor_count', header: 'Target', render: (r: any) => r.target_vendor_count },
    { key: 'vendor_gap', header: 'Gap', render: (r: any) => Number(r.vendor_count_today ?? 0) - Number(r.target_vendor_count ?? 0) },
    { key: 'our_threat_kind', header: 'Our Threat', render: (r: any) => r.our_threat_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const actionsColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'action_at', header: 'When', render: (r: any) => new Date(r.action_at).toLocaleDateString('en-IN') },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const focusColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'vendor_count_today', header: 'Vendors Today', render: (r: any) => r.vendor_count_today },
    { key: 'target_vendor_count', header: 'Target', render: (r: any) => r.target_vendor_count },
    { key: 'vendor_gap', header: 'Gap', render: (r: any) => r.vendor_gap },
    { key: 'our_threat_kind', header: 'Threat', render: (r: any) => r.our_threat_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const kindColumns: Column<any>[] = [
    { key: 'our_threat_kind', header: 'Threat Kind', render: (r: any) => r.our_threat_kind },
    { key: 'pressure_count', header: 'Count', render: (r: any) => r.pressure_count },
    { key: 'avg_vendor_count_today', header: 'Avg Vendors', render: (r: any) => r.avg_vendor_count_today },
    { key: 'avg_target_vendor_count', header: 'Avg Target', render: (r: any) => r.avg_target_vendor_count },
  ];

  const funnelColumns: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'pressure_count', header: 'Count', render: (r: any) => r.pressure_count },
    { key: 'total_vendor_gap', header: 'Total Gap', render: (r: any) => r.total_vendor_gap },
  ];

  const trendColumns: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'pressure_count', header: 'Pressures', render: (r: any) => r.pressure_count },
    { key: 'escalated_count', header: 'Escalated', render: (r: any) => r.escalated_count },
    { key: 'resolved_count', header: 'Resolved', render: (r: any) => r.resolved_count },
    { key: 'avg_vendor_gap', header: 'Avg Gap', render: (r: any) => r.avg_vendor_gap },
  ];

  const ownerColumns: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'pressure_count', header: 'Pressures', render: (r: any) => r.pressure_count },
    { key: 'action_count', header: 'Actions', render: (r: any) => r.action_count },
    { key: 'open_action_count', header: 'Open', render: (r: any) => r.open_action_count },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Hospital Chain Quarterly Vendor Consolidation Pressure</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track chain procurement consolidation moves quarter-by-quarter & deploy counter-actions before we get dropped.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 16, marginBottom: 32 }}>
        <div style={{ padding: 16, background: '#f4f4f5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Chains Tracked</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalPressure}</div>
        </div>
        <div style={{ padding: 16, background: '#f4f4f5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Escalated</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{escalatedCount}</div>
        </div>
        <div style={{ padding: 16, background: '#f4f4f5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Vendor Gap</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalGap}</div>
        </div>
        <div style={{ padding: 16, background: '#f4f4f5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Counter Actions</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalActions}</div>
        </div>
        <div style={{ padding: 16, background: '#f4f4f5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Open Actions</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{openActions}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Threat Focus (Reduced / Eliminated & Active)</h2>
        <DataTable
          rows={focus}
          columns={focusColumns}
          emptyMessage="No active threats to focus on"
          rowKey={(r: any, i: number) => String(r.id ?? `${r.chain_name}-${i}`)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Chain Consolidation Pressure</h2>
        <DataTable
          rows={pressure}
          columns={pressureColumns}
          emptyMessage="No pressure records"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Counter Actions Log</h2>
        <DataTable
          rows={actions}
          columns={actionsColumns}
          emptyMessage="No counter actions logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(360px, 1fr))', gap: 24, marginBottom: 32 }}>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Threat Kind Distribution</h2>
          <DataTable
            rows={kind}
            columns={kindColumns}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.our_threat_kind ?? i)}
          />
        </div>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Status Funnel</h2>
          <DataTable
            rows={funnel}
            columns={funnelColumns}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.status ?? i)}
          />
        </div>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Quarterly Trend</h2>
          <DataTable
            rows={trend}
            columns={trendColumns}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
          />
        </div>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Owner Load</h2>
          <DataTable
            rows={owners}
            columns={ownerColumns}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
          />
        </div>
      </section>
    </main>
  );
}
