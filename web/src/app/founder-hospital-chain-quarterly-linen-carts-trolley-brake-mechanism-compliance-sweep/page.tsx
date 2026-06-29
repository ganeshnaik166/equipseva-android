import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/data-table';

export const dynamic = 'force-dynamic';

type ChainRow = { chain_name: string; inspected: number; pass_count: number; fail_count: number; seized_count: number; avg_defect: number };
type BrakeRow = { brake_mechanism_kind: string; total: number; failing: number; fail_pct: number };
type OverdueRow = { inspection_ref: string; chain_name: string; remediation_kind: string; vendor_name: string; sla_hours: number; cost_rupees: number };
type HotRow = { chain_name: string; hospital_branch: string; fail_or_seized: number; avg_defect: number };
type VendorRow = { vendor_name: string; jobs: number; total_spend: number; closed_jobs: number };
type TypeRow = { trolley_type: string; inspected: number; avg_defect: number; avg_load_kg: number };
type DueRow = { chain_name: string; hospital_branch: string; trolley_asset_tag: string; next_due_at: string; brake_status: string };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [chains, brakes, overdue, hot, vendors, types, due] = await Promise.all([
    sb.rpc('r2983_summary_by_chain'),
    sb.rpc('r2983_brake_kind_failure_rate'),
    sb.rpc('r2983_overdue_remediations'),
    sb.rpc('r2983_branch_hotlist'),
    sb.rpc('r2983_vendor_spend'),
    sb.rpc('r2983_trolley_type_defects'),
    sb.rpc('r2983_due_within_14d'),
  ]);

  const chainCols: Column<ChainRow>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Inspected', accessor: (r) => r.inspected },
    { header: 'Pass', accessor: (r) => r.pass_count },
    { header: 'Fail', accessor: (r) => r.fail_count },
    { header: 'Seized', accessor: (r) => r.seized_count },
    { header: 'Avg Defect', accessor: (r) => r.avg_defect },
  ];
  const brakeCols: Column<BrakeRow>[] = [
    { header: 'Brake Kind', accessor: (r) => r.brake_mechanism_kind },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Failing', accessor: (r) => r.failing },
    { header: 'Fail %', accessor: (r) => r.fail_pct },
  ];
  const overdueCols: Column<OverdueRow>[] = [
    { header: 'Inspection', accessor: (r) => r.inspection_ref },
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Remediation', accessor: (r) => r.remediation_kind },
    { header: 'Vendor', accessor: (r) => r.vendor_name },
    { header: 'SLA hrs', accessor: (r) => r.sla_hours },
    { header: 'Cost ₹', accessor: (r) => r.cost_rupees },
  ];
  const hotCols: Column<HotRow>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Branch', accessor: (r) => r.hospital_branch },
    { header: 'Fail/Seized', accessor: (r) => r.fail_or_seized },
    { header: 'Avg Defect', accessor: (r) => r.avg_defect },
  ];
  const vendorCols: Column<VendorRow>[] = [
    { header: 'Vendor', accessor: (r) => r.vendor_name },
    { header: 'Jobs', accessor: (r) => r.jobs },
    { header: 'Spend ₹', accessor: (r) => r.total_spend },
    { header: 'Closed', accessor: (r) => r.closed_jobs },
  ];
  const typeCols: Column<TypeRow>[] = [
    { header: 'Trolley Type', accessor: (r) => r.trolley_type },
    { header: 'Inspected', accessor: (r) => r.inspected },
    { header: 'Avg Defect', accessor: (r) => r.avg_defect },
    { header: 'Avg Load kg', accessor: (r) => r.avg_load_kg },
  ];
  const dueCols: Column<DueRow>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Branch', accessor: (r) => r.hospital_branch },
    { header: 'Asset Tag', accessor: (r) => r.trolley_asset_tag },
    { header: 'Next Due', accessor: (r) => new Date(r.next_due_at).toLocaleDateString() },
    { header: 'Brake Status', accessor: (r) => r.brake_status },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain — Quarterly Linen-Cart & Trolley Brake-Mechanism Sweep</h1>
        <p className="text-sm text-gray-600">Round r2983 · Batch 420 milestone · Brake status across chains: pass / fail / seized &gt; thresholds.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Summary by Chain</h2>
        <DataTable<ChainRow>
          rows={(chains.data ?? []) as ChainRow[]}
          columns={chainCols}
          emptyMessage="No chain data."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Brake Mechanism Failure Rate</h2>
        <DataTable<BrakeRow>
          rows={(brakes.data ?? []) as BrakeRow[]}
          columns={brakeCols}
          emptyMessage="No brake data."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Overdue Remediations</h2>
        <DataTable<OverdueRow>
          rows={(overdue.data ?? []) as OverdueRow[]}
          columns={overdueCols}
          emptyMessage="None overdue."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Branch Hotlist (Fail/Seized &gt; 0)</h2>
        <DataTable<HotRow>
          rows={(hot.data ?? []) as HotRow[]}
          columns={hotCols}
          emptyMessage="No branches flagged."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Vendor Spend</h2>
        <DataTable<VendorRow>
          rows={(vendors.data ?? []) as VendorRow[]}
          columns={vendorCols}
          emptyMessage="No vendor jobs."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Trolley Type Defects</h2>
        <DataTable<TypeRow>
          rows={(types.data ?? []) as TypeRow[]}
          columns={typeCols}
          emptyMessage="No trolley types."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Due Within 14 Days</h2>
        <DataTable<DueRow>
          rows={(due.data ?? []) as DueRow[]}
          columns={dueCols}
          emptyMessage="None due soon."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>
    </main>
  );
}
