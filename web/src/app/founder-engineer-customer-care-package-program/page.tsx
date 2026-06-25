import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function EngineerCustomerCarePackageProgramPage() {
  const supabase = await getSupabaseServerClient();

  const [
    packagesRes,
    actionsRes,
    topValueRes,
    kindDistRes,
    statusFunnelRes,
    trendRes,
    ownerLoadRes,
  ] = await Promise.all([
    supabase.rpc('list_care_packages_r2638'),
    supabase.rpc('list_followup_actions_r2638'),
    supabase.rpc('top_value_focus_r2638'),
    supabase.rpc('package_kind_distribution_r2638'),
    supabase.rpc('status_funnel_r2638'),
    supabase.rpc('monthly_package_trend_r2638'),
    supabase.rpc('owner_load_r2638'),
  ]);

  const packages = (packagesRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const topValue = (topValueRes.data ?? []) as any[];
  const kindDist = (kindDistRes.data ?? []) as any[];
  const statusFunnel = (statusFunnelRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const ownerLoad = (ownerLoadRes.data ?? []) as any[];

  const fmtDate = (v: any) => {
    if (!v) return '—';
    try {
      return new Date(v).toISOString().slice(0, 16).replace('T', ' ');
    } catch {
      return String(v);
    }
  };

  const packageCols: Column<any>[] = [
    { key: 'sent_at', header: 'Sent', render: (r: any) => fmtDate(r.sent_at) },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'hospital_user_id', header: 'Hospital', render: (r: any) => String(r.hospital_user_id ?? '').slice(0, 8) },
    { key: 'package_kind', header: 'Kind', render: (r: any) => String(r.package_kind) },
    { key: 'value_rupees', header: 'Value (Rs)', render: (r: any) => String(r.value_rupees ?? 0) },
    { key: 'received_signoff', header: 'Signoff', render: (r: any) => (r.received_signoff ? 'yes' : 'no') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => (r.owner_email ?? '—') },
    { key: 'customer_reaction_md', header: 'Reaction', render: (r: any) => (r.customer_reaction_md ?? '—') },
    { key: 'notes', header: 'Notes', render: (r: any) => (r.notes ?? '—') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_at', header: 'When', render: (r: any) => fmtDate(r.action_at) },
    { key: 'package_id', header: 'Package', render: (r: any) => String(r.package_id ?? '').slice(0, 8) },
    { key: 'action_kind', header: 'Kind', render: (r: any) => String(r.action_kind) },
    { key: 'outcome', header: 'Outcome', render: (r: any) => String(r.outcome) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => (r.owner_email ?? '—') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status) },
    { key: 'notes', header: 'Notes', render: (r: any) => (r.notes ?? '—') },
  ];

  const topValueCols: Column<any>[] = [
    { key: 'hospital_user_id', header: 'Hospital', render: (r: any) => String(r.hospital_user_id ?? '').slice(0, 8) },
    { key: 'packages', header: 'Packages', render: (r: any) => String(r.packages) },
    { key: 'total_value_rupees', header: 'Total (Rs)', render: (r: any) => String(r.total_value_rupees) },
    { key: 'avg_value_rupees', header: 'Avg (Rs)', render: (r: any) => String(r.avg_value_rupees ?? '—') },
  ];

  const kindCols: Column<any>[] = [
    { key: 'package_kind', header: 'Kind', render: (r: any) => String(r.package_kind) },
    { key: 'packages', header: 'Packages', render: (r: any) => String(r.packages) },
    { key: 'total_value_rupees', header: 'Total (Rs)', render: (r: any) => String(r.total_value_rupees) },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => String(r.status) },
    { key: 'packages', header: 'Packages', render: (r: any) => String(r.packages) },
    { key: 'signed_off', header: 'Signed Off', render: (r: any) => String(r.signed_off) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => fmtDate(r.month_start).slice(0, 7) },
    { key: 'packages', header: 'Packages', render: (r: any) => String(r.packages) },
    { key: 'total_value_rupees', header: 'Total (Rs)', render: (r: any) => String(r.total_value_rupees) },
    { key: 'avg_value_rupees', header: 'Avg (Rs)', render: (r: any) => String(r.avg_value_rupees ?? '—') },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email) },
    { key: 'open_actions', header: 'Open', render: (r: any) => String(r.open_actions) },
    { key: 'done_actions', header: 'Done', render: (r: any) => String(r.done_actions) },
    { key: 'dropped_actions', header: 'Dropped', render: (r: any) => String(r.dropped_actions) },
    { key: 'total_actions', header: 'Total', render: (r: any) => String(r.total_actions) },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1280px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>
        Engineer Customer Care Package Program
      </h1>
      <p style={{ color: '#555', marginBottom: '24px', fontSize: '14px' }}>
        Track care packages engineers send to hospital customers & structured follow-up actions to deepen loyalty.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Care Packages</h2>
        <DataTable
          rows={packages}
          columns={packageCols}
          emptyMessage="No care packages logged yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Follow-up Actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No follow-up actions yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Top Hospitals by Value</h2>
        <DataTable
          rows={topValue}
          columns={topValueCols}
          emptyMessage="No value rollup yet"
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Package Kind Distribution</h2>
        <DataTable
          rows={kindDist}
          columns={kindCols}
          emptyMessage="No kind distribution yet"
          rowKey={(r: any, i: number) => String(r.package_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Status Funnel</h2>
        <DataTable
          rows={statusFunnel}
          columns={statusCols}
          emptyMessage="No status data yet"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Monthly Package Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data yet"
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Owner Load</h2>
        <DataTable
          rows={ownerLoad}
          columns={ownerCols}
          emptyMessage="No owner load data yet"
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </main>
  );
}
