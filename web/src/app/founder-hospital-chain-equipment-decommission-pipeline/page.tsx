import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    decommissions,
    complianceLog,
    buybackFocus,
    disposalBreakdown,
    complianceSummary,
    monthlyTrend,
    ownerLoad,
  ] = await Promise.all([
    supabase.rpc('list_decommissions_r2571'),
    supabase.rpc('list_compliance_log_r2571'),
    supabase.rpc('top_buyback_focus_r2571'),
    supabase.rpc('disposal_kind_breakdown_r2571'),
    supabase.rpc('compliance_status_summary_r2571'),
    supabase.rpc('monthly_decomm_trend_r2571'),
    supabase.rpc('owner_load_r2571'),
  ]);

  const decommRows = (decommissions.data ?? []) as any[];
  const logRows = (complianceLog.data ?? []) as any[];
  const buybackRows = (buybackFocus.data ?? []) as any[];
  const disposalRows = (disposalBreakdown.data ?? []) as any[];
  const complianceRows = (complianceSummary.data ?? []) as any[];
  const trendRows = (monthlyTrend.data ?? []) as any[];
  const ownerRows = (ownerLoad.data ?? []) as any[];

  const fmtDate = (v: any) => (v ? new Date(v).toISOString().slice(0, 10) : '—');
  const fmtRupees = (v: any) => `₹${Number(v ?? 0).toLocaleString('en-IN')}`;

  const decommCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'equipment_kind', header: 'Kind', render: (r: any) => r.equipment_kind },
    { key: 'decommission_reason', header: 'Reason', render: (r: any) => r.decommission_reason },
    { key: 'disposal_kind', header: 'Disposal', render: (r: any) => r.disposal_kind },
    { key: 'revenue_buyback_rupees', header: 'Buyback', render: (r: any) => fmtRupees(r.revenue_buyback_rupees) },
    { key: 'compliance_status', header: 'Compliance', render: (r: any) => r.compliance_status },
    { key: 'decomm_planned_at', header: 'Planned', render: (r: any) => fmtDate(r.decomm_planned_at) },
    { key: 'decomm_completed_at', header: 'Completed', render: (r: any) => fmtDate(r.decomm_completed_at) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const logCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'log_at', header: 'Logged', render: (r: any) => fmtDate(r.log_at) },
    { key: 'compliance_check_kind', header: 'Check', render: (r: any) => r.compliance_check_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const buybackCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'decomm_count', header: 'Decomm Count', render: (r: any) => String(r.decomm_count ?? 0) },
    { key: 'total_buyback_rupees', header: 'Buyback Total', render: (r: any) => fmtRupees(r.total_buyback_rupees) },
  ];

  const disposalCols: Column<any>[] = [
    { key: 'disposal_kind', header: 'Disposal Kind', render: (r: any) => r.disposal_kind },
    { key: 'decomm_count', header: 'Count', render: (r: any) => String(r.decomm_count ?? 0) },
    { key: 'total_buyback_rupees', header: 'Buyback Total', render: (r: any) => fmtRupees(r.total_buyback_rupees) },
  ];

  const complianceCols: Column<any>[] = [
    { key: 'compliance_status', header: 'Compliance', render: (r: any) => r.compliance_status },
    { key: 'decomm_count', header: 'Count', render: (r: any) => String(r.decomm_count ?? 0) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'decomm_count', header: 'Decomm Count', render: (r: any) => String(r.decomm_count ?? 0) },
    { key: 'total_buyback_rupees', header: 'Buyback Total', render: (r: any) => fmtRupees(r.total_buyback_rupees) },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'decomm_count', header: 'Decomm Count', render: (r: any) => String(r.decomm_count ?? 0) },
    { key: 'open_compliance_logs', header: 'Open Compliance Logs', render: (r: any) => String(r.open_compliance_logs ?? 0) },
  ];

  return (
    <main className="mx-auto max-w-7xl px-6 py-10 space-y-10">
      <header>
        <h1 className="text-2xl font-semibold">Hospital Chain Equipment Decommission Pipeline</h1>
        <p className="text-sm text-gray-600 mt-1">
          Chain & equipment & reason & disposal kind & buyback revenue & compliance status.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">Decommissions</h2>
        <DataTable
          rows={decommRows}
          columns={decommCols}
          emptyMessage="No decommissions yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Compliance Log</h2>
        <DataTable
          rows={logRows}
          columns={logCols}
          emptyMessage="No compliance log entries."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Top Buyback Focus by Chain</h2>
        <DataTable
          rows={buybackRows}
          columns={buybackCols}
          emptyMessage="No buyback data."
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Disposal Kind Breakdown</h2>
        <DataTable
          rows={disposalRows}
          columns={disposalCols}
          emptyMessage="No disposal data."
          rowKey={(r: any, i: number) => String(r.disposal_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Compliance Status Summary</h2>
        <DataTable
          rows={complianceRows}
          columns={complianceCols}
          emptyMessage="No compliance data."
          rowKey={(r: any, i: number) => String(r.compliance_status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Monthly Decomm Trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Owner Load</h2>
        <DataTable
          rows={ownerRows}
          columns={ownerCols}
          emptyMessage="No owner load data."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </main>
  );
}
