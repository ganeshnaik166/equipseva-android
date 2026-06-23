import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '-';
  try {
    return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return String(s);
  }
}

function fmtMonth(s: string | null | undefined): string {
  if (!s) return '-';
  try {
    return new Date(s).toLocaleString('en-IN', { year: 'numeric', month: 'short' });
  } catch {
    return String(s);
  }
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [bridges, revLog, topRev, feas, kindDist, monthlyTrend, broken] = await Promise.all([
    supabase.rpc('list_bridges_r2564'),
    supabase.rpc('list_revenue_log_r2564'),
    supabase.rpc('top_revenue_bridges_r2564'),
    supabase.rpc('feasibility_breakdown_r2564'),
    supabase.rpc('bridge_kind_distribution_r2564'),
    supabase.rpc('monthly_revenue_trend_r2564'),
    supabase.rpc('broken_focus_r2564'),
  ]);

  const bridgeCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'equipment_kind', header: 'Kind', render: (r: any) => r.equipment_kind },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'data_export_feasibility', header: 'Feasibility', render: (r: any) => r.data_export_feasibility },
    { key: 'bridge_kind', header: 'Bridge', render: (r: any) => r.bridge_kind },
    { key: 'frequency_kind', header: 'Frequency', render: (r: any) => r.frequency_kind },
    { key: 'revenue_from_data_rupees', header: 'Revenue', render: (r: any) => fmtRupees(r.revenue_from_data_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const revCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label ?? '-' },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'observed_at', header: 'Observed', render: (r: any) => fmtDate(r.observed_at) },
    { key: 'revenue_event_kind', header: 'Event', render: (r: any) => r.revenue_event_kind },
    { key: 'revenue_rupees', header: 'Revenue', render: (r: any) => fmtRupees(r.revenue_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'equipment_kind', header: 'Kind', render: (r: any) => r.equipment_kind },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'bridge_kind', header: 'Bridge', render: (r: any) => r.bridge_kind },
    { key: 'frequency_kind', header: 'Frequency', render: (r: any) => r.frequency_kind },
    { key: 'total_revenue_rupees', header: 'Total Revenue', render: (r: any) => fmtRupees(r.total_revenue_rupees) },
    { key: 'events_count', header: 'Events', render: (r: any) => r.events_count },
  ];

  const feasCols: Column<any>[] = [
    { key: 'data_export_feasibility', header: 'Feasibility', render: (r: any) => r.data_export_feasibility },
    { key: 'equipment_count', header: 'Equipment', render: (r: any) => r.equipment_count },
    { key: 'total_revenue_rupees', header: 'Revenue', render: (r: any) => fmtRupees(r.total_revenue_rupees) },
    { key: 'live_count', header: 'Live', render: (r: any) => r.live_count },
  ];

  const kindCols: Column<any>[] = [
    { key: 'bridge_kind', header: 'Bridge Kind', render: (r: any) => r.bridge_kind },
    { key: 'equipment_count', header: 'Equipment', render: (r: any) => r.equipment_count },
    { key: 'total_revenue_rupees', header: 'Revenue', render: (r: any) => fmtRupees(r.total_revenue_rupees) },
    { key: 'pct_live', header: '% Live', render: (r: any) => (r.pct_live ?? 0) + '%' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => fmtMonth(r.month_start) },
    { key: 'events_count', header: 'Events', render: (r: any) => r.events_count },
    { key: 'total_revenue_rupees', header: 'Revenue', render: (r: any) => fmtRupees(r.total_revenue_rupees) },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
  ];

  const brokenCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'equipment_kind', header: 'Kind', render: (r: any) => r.equipment_kind },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'bridge_kind', header: 'Bridge', render: (r: any) => r.bridge_kind },
    { key: 'frequency_kind', header: 'Frequency', render: (r: any) => r.frequency_kind },
    { key: 'revenue_from_data_rupees', header: 'Revenue', render: (r: any) => fmtRupees(r.revenue_from_data_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '0.5rem' }}>
        Customer Equipment Data Quality & Air-Gap Bridge
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Per-equipment data export feasibility, bridge kind & frequency, and revenue earned from data products.
        Broken bridges and "no-export" equipment surface first for vendor escalation.
      </p>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Top Revenue Bridges</h2>
        <DataTable
          rows={topRev.data ?? []}
          columns={topCols}
          emptyMessage="No bridge revenue ranked yet."
          rowKey={(r: any, i: number) => String(r.bridge_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Feasibility Breakdown</h2>
        <DataTable
          rows={feas.data ?? []}
          columns={feasCols}
          emptyMessage="No feasibility data yet."
          rowKey={(r: any, i: number) => String(r.data_export_feasibility ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Bridge Kind Distribution</h2>
        <DataTable
          rows={kindDist.data ?? []}
          columns={kindCols}
          emptyMessage="No bridge kinds recorded."
          rowKey={(r: any, i: number) => String(r.bridge_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Monthly Revenue Trend</h2>
        <DataTable
          rows={monthlyTrend.data ?? []}
          columns={trendCols}
          emptyMessage="No monthly trend yet."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>
          Broken & No-Export Focus
        </h2>
        <DataTable
          rows={broken.data ?? []}
          columns={brokenCols}
          emptyMessage="No broken bridges — all clear."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>All Bridges</h2>
        <DataTable
          rows={bridges.data ?? []}
          columns={bridgeCols}
          emptyMessage="No equipment bridges recorded yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Revenue Log</h2>
        <DataTable
          rows={revLog.data ?? []}
          columns={revCols}
          emptyMessage="No revenue events logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
