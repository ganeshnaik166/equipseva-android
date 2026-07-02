import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderCustomerEquipmentDataPortabilityExportPage() {
  const supabase = await getSupabaseServerClient();

  const [
    portabilityRes,
    revenueLogRes,
    topRevenueRes,
    feasibilityRes,
    formatRes,
    dpdpRes,
    trendRes,
  ] = await Promise.all([
    supabase.rpc('list_portability_r2584'),
    supabase.rpc('list_revenue_log_r2584'),
    supabase.rpc('top_revenue_focus_r2584'),
    supabase.rpc('feasibility_distribution_r2584'),
    supabase.rpc('format_kind_breakdown_r2584'),
    supabase.rpc('dpdp_compliance_summary_r2584'),
    supabase.rpc('monthly_revenue_trend_r2584'),
  ]);

  const portability = (portabilityRes.data ?? []) as any[];
  const revenueLog = (revenueLogRes.data ?? []) as any[];
  const topRevenue = (topRevenueRes.data ?? []) as any[];
  const feasibility = (feasibilityRes.data ?? []) as any[];
  const formatBreakdown = (formatRes.data ?? []) as any[];
  const dpdp = (dpdpRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];

  const fmtDt = (s: string | null) =>
    s ? new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }) : '—';
  const fmtRup = (n: number | null | undefined) =>
    n == null ? '—' : `Rs ${Number(n).toLocaleString('en-IN')}`;

  const portabilityCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'equipment_kind', header: 'Kind', render: (r: any) => r.equipment_kind },
    { key: 'export_feasibility', header: 'Feasibility', render: (r: any) => r.export_feasibility },
    { key: 'format_kind', header: 'Format', render: (r: any) => r.format_kind },
    { key: 'revenue_rupees', header: 'Revenue', render: (r: any) => fmtRup(r.revenue_rupees) },
    { key: 'dpdp_compliance', header: 'DPDP', render: (r: any) => r.dpdp_compliance },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const revenueLogCols: Column<any>[] = [
    { key: 'observed_at', header: 'Observed', render: (r: any) => fmtDt(r.observed_at) },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'revenue_kind', header: 'Kind', render: (r: any) => r.revenue_kind },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => fmtRup(r.amount_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const topRevenueCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'equipment_kind', header: 'Kind', render: (r: any) => r.equipment_kind },
    { key: 'export_feasibility', header: 'Feasibility', render: (r: any) => r.export_feasibility },
    { key: 'format_kind', header: 'Format', render: (r: any) => r.format_kind },
    { key: 'revenue_rupees', header: 'Revenue', render: (r: any) => fmtRup(r.revenue_rupees) },
    { key: 'dpdp_compliance', header: 'DPDP', render: (r: any) => r.dpdp_compliance },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const feasibilityCols: Column<any>[] = [
    { key: 'export_feasibility', header: 'Feasibility', render: (r: any) => r.export_feasibility },
    { key: 'equipment_count', header: 'Count', render: (r: any) => r.equipment_count },
    { key: 'total_revenue_rupees', header: 'Revenue', render: (r: any) => fmtRup(r.total_revenue_rupees) },
  ];

  const formatCols: Column<any>[] = [
    { key: 'format_kind', header: 'Format', render: (r: any) => r.format_kind },
    { key: 'equipment_count', header: 'Count', render: (r: any) => r.equipment_count },
    { key: 'total_revenue_rupees', header: 'Revenue', render: (r: any) => fmtRup(r.total_revenue_rupees) },
  ];

  const dpdpCols: Column<any>[] = [
    { key: 'dpdp_compliance', header: 'DPDP', render: (r: any) => r.dpdp_compliance },
    { key: 'equipment_count', header: 'Count', render: (r: any) => r.equipment_count },
    { key: 'total_revenue_rupees', header: 'Revenue', render: (r: any) => fmtRup(r.total_revenue_rupees) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_bucket', header: 'Month', render: (r: any) => r.month_bucket },
    { key: 'log_count', header: 'Log entries', render: (r: any) => r.log_count },
    { key: 'total_amount_rupees', header: 'Amount', render: (r: any) => fmtRup(r.total_amount_rupees) },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>
          Customer Equipment Data Portability & Export
        </h1>
        <p style={{ color: '#555', maxWidth: 820 }}>
          Per-equipment data export feasibility (yes / partial / no), interchange format
          (DICOM, HL7, CSV, proprietary), DPDP compliance state and the revenue earned from
          subscriptions, API seats, report packs and training credits.
        </p>
      </header>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top revenue equipment</h2>
        <DataTable
          rows={topRevenue}
          columns={topRevenueCols}
          emptyMessage="No revenue equipment on file."
          rowKey={(r: any, i: number) => String(r.equipment_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Feasibility distribution</h2>
        <DataTable
          rows={feasibility}
          columns={feasibilityCols}
          emptyMessage="No feasibility rows."
          rowKey={(r: any, i: number) => String(r.export_feasibility ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Format kind breakdown</h2>
        <DataTable
          rows={formatBreakdown}
          columns={formatCols}
          emptyMessage="No format rows."
          rowKey={(r: any, i: number) => String(r.format_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>DPDP compliance summary</h2>
        <DataTable
          rows={dpdp}
          columns={dpdpCols}
          emptyMessage="No DPDP rows."
          rowKey={(r: any, i: number) => String(r.dpdp_compliance ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly revenue trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend rows."
          rowKey={(r: any, i: number) => String(r.month_bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All portability equipment</h2>
        <DataTable
          rows={portability}
          columns={portabilityCols}
          emptyMessage="No portability equipment."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Revenue log</h2>
        <DataTable
          rows={revenueLog}
          columns={revenueLogCols}
          emptyMessage="No revenue log entries."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
