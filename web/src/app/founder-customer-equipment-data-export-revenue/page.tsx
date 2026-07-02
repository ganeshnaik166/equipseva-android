import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [exportsRes, logRes, topRes, kindRes, statusRes, trendRes, ownerRes] = await Promise.all([
    supabase.rpc('list_data_exports_r2616'),
    supabase.rpc('list_renewal_log_r2616'),
    supabase.rpc('top_revenue_exports_r2616'),
    supabase.rpc('export_kind_distribution_r2616'),
    supabase.rpc('status_funnel_r2616'),
    supabase.rpc('monthly_revenue_trend_r2616'),
    supabase.rpc('owner_load_r2616'),
  ]);

  const exportsRows = (exportsRes.data ?? []) as any[];
  const logRows = (logRes.data ?? []) as any[];
  const topRows = (topRes.data ?? []) as any[];
  const kindRows = (kindRes.data ?? []) as any[];
  const statusRows = (statusRes.data ?? []) as any[];
  const trendRows = (trendRes.data ?? []) as any[];
  const ownerRows = (ownerRes.data ?? []) as any[];

  const fmtRupees = (n: number | null | undefined) =>
    n == null ? '—' : `₹${Number(n).toLocaleString('en-IN')}`;
  const fmtDate = (s: string | null | undefined) =>
    s ? new Date(s).toLocaleString('en-IN') : '—';

  const exportsCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'export_kind', header: 'Kind', render: (r: any) => r.export_kind },
    { key: 'monthly_revenue_rupees', header: 'Monthly', render: (r: any) => fmtRupees(r.monthly_revenue_rupees) },
    { key: 'contract_months', header: 'Months', render: (r: any) => r.contract_months },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const logCols: Column<any>[] = [
    { key: 'event_at', header: 'When', render: (r: any) => fmtDate(r.event_at) },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label ?? '—' },
    { key: 'event_kind', header: 'Event', render: (r: any) => r.event_kind },
    { key: 'revenue_delta_rupees', header: 'Delta', render: (r: any) => fmtRupees(r.revenue_delta_rupees) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const topCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'export_kind', header: 'Kind', render: (r: any) => r.export_kind },
    { key: 'monthly_revenue_rupees', header: 'Monthly', render: (r: any) => fmtRupees(r.monthly_revenue_rupees) },
    { key: 'annualized_rupees', header: 'Annualized', render: (r: any) => fmtRupees(r.annualized_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const kindCols: Column<any>[] = [
    { key: 'export_kind', header: 'Kind', render: (r: any) => r.export_kind },
    { key: 'contract_count', header: 'Contracts', render: (r: any) => r.contract_count },
    { key: 'total_monthly_rupees', header: 'Total Monthly', render: (r: any) => fmtRupees(r.total_monthly_rupees) },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'contract_count', header: 'Contracts', render: (r: any) => r.contract_count },
    { key: 'total_monthly_rupees', header: 'Total Monthly', render: (r: any) => fmtRupees(r.total_monthly_rupees) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start },
    { key: 'net_delta_rupees', header: 'Net Delta', render: (r: any) => fmtRupees(r.net_delta_rupees) },
    { key: 'event_count', header: 'Events', render: (r: any) => r.event_count },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'active_contracts', header: 'Active', render: (r: any) => r.active_contracts },
    { key: 'total_monthly_rupees', header: 'Monthly Book', render: (r: any) => fmtRupees(r.total_monthly_rupees) },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 600, marginBottom: 8 }}>
        Customer Equipment Data Export Revenue
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Hospital data-export contracts (CSV feeds, API seats, report subs & analytics packs)
        tracked as recurring revenue with renewal & churn events.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Export Contracts</h2>
        <DataTable
          rows={exportsRows}
          columns={exportsCols}
          emptyMessage="No export contracts on file."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Renewal & Churn Log</h2>
        <DataTable
          rows={logRows}
          columns={logCols}
          emptyMessage="No renewal events recorded."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Revenue Exports</h2>
        <DataTable
          rows={topRows}
          columns={topCols}
          emptyMessage="No revenue rows yet."
          rowKey={(r: any, i: number) => String(r.equipment_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Export Kind Distribution</h2>
        <DataTable
          rows={kindRows}
          columns={kindCols}
          emptyMessage="No kinds aggregated."
          rowKey={(r: any, i: number) => String(r.export_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Status Funnel</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No status data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly Revenue Trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Owner Load</h2>
        <DataTable
          rows={ownerRows}
          columns={ownerCols}
          emptyMessage="No owner rows."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </div>
  );
}
