import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ChainRow = { chain_name: string; inspections: number; compliant: number; critical_fails: number; avg_freeplay: number };
type QuarterRow = { inspection_quarter: string; total: number; pass_rate: number; critical_count: number };
type CriticalRow = { chain_name: string; hospital_unit: string; ward_zone: string; trolley_asset_tag: string; swivel_freeplay_mm: number; inspected_on: string };
type VendorRow = { vendor_name: string; actions: number; total_spend: number; completed: number };
type ModelRow = { trolley_model: string; inspections: number; fail_rate: number };
type ActionRow = { action_kind: string; total: number; completed: number; pending: number; total_cost: number };
type UnsignedRow = { chain_name: string; hospital_unit: string; trolley_asset_tag: string; inspection_quarter: string; compliance_status: string; inspected_on: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [chains, quarters, critical, vendors, models, actions, unsigned] = await Promise.all([
    supabase.rpc('r3055_chain_summary'),
    supabase.rpc('r3055_quarterly_compliance'),
    supabase.rpc('r3055_top_critical_units'),
    supabase.rpc('r3055_vendor_spend'),
    supabase.rpc('r3055_model_failure_rate'),
    supabase.rpc('r3055_action_kind_breakdown'),
    supabase.rpc('r3055_unsigned_inspections'),
  ]);

  const chainCols: Column<ChainRow>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Inspections', accessor: (r) => r.inspections },
    { header: 'Compliant', accessor: (r) => r.compliant },
    { header: 'Critical Fails', accessor: (r) => r.critical_fails },
    { header: 'Avg Freeplay (mm)', accessor: (r) => r.avg_freeplay },
  ];

  const quarterCols: Column<QuarterRow>[] = [
    { header: 'Quarter', accessor: (r) => r.inspection_quarter },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Pass Rate %', accessor: (r) => r.pass_rate },
    { header: 'Critical', accessor: (r) => r.critical_count },
  ];

  const criticalCols: Column<CriticalRow>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Unit', accessor: (r) => r.hospital_unit },
    { header: 'Ward', accessor: (r) => r.ward_zone },
    { header: 'Asset', accessor: (r) => r.trolley_asset_tag },
    { header: 'Freeplay mm', accessor: (r) => r.swivel_freeplay_mm },
    { header: 'Inspected', accessor: (r) => r.inspected_on },
  ];

  const vendorCols: Column<VendorRow>[] = [
    { header: 'Vendor', accessor: (r) => r.vendor_name },
    { header: 'Actions', accessor: (r) => r.actions },
    { header: 'Spend (Rs)', accessor: (r) => r.total_spend },
    { header: 'Completed', accessor: (r) => r.completed },
  ];

  const modelCols: Column<ModelRow>[] = [
    { header: 'Model', accessor: (r) => r.trolley_model },
    { header: 'Inspections', accessor: (r) => r.inspections },
    { header: 'Fail Rate %', accessor: (r) => r.fail_rate },
  ];

  const actionCols: Column<ActionRow>[] = [
    { header: 'Action Kind', accessor: (r) => r.action_kind },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Completed', accessor: (r) => r.completed },
    { header: 'Pending', accessor: (r) => r.pending },
    { header: 'Cost (Rs)', accessor: (r) => r.total_cost },
  ];

  const unsignedCols: Column<UnsignedRow>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Unit', accessor: (r) => r.hospital_unit },
    { header: 'Asset', accessor: (r) => r.trolley_asset_tag },
    { header: 'Quarter', accessor: (r) => r.inspection_quarter },
    { header: 'Status', accessor: (r) => r.compliance_status },
    { header: 'Inspected', accessor: (r) => r.inspected_on },
  ];

  return (
    <div style={{ padding: 24, display: 'grid', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>Hospital Chain — Quarterly Linen Trolley Brake Caster &amp; Wheel Lock Compliance</h1>
        <p style={{ color: '#666', marginTop: 4 }}>Round r3055 — caster brake &amp; wheel-lock pass rates across hospital chains; flags critical fails &gt;= high severity and tracks remediation spend.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Chain Summary</h2>
        <DataTable<ChainRow>
          rows={(chains.data ?? []) as ChainRow[]}
          columns={chainCols}
          emptyMessage="No chain data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Quarterly Compliance</h2>
        <DataTable<QuarterRow>
          rows={(quarters.data ?? []) as QuarterRow[]}
          columns={quarterCols}
          emptyMessage="No quarterly data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Top Critical Units (severity &gt;= high)</h2>
        <DataTable<CriticalRow>
          rows={(critical.data ?? []) as CriticalRow[]}
          columns={criticalCols}
          emptyMessage="No critical units"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Vendor Spend</h2>
        <DataTable<VendorRow>
          rows={(vendors.data ?? []) as VendorRow[]}
          columns={vendorCols}
          emptyMessage="No vendor data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Trolley Model Failure Rate</h2>
        <DataTable<ModelRow>
          rows={(models.data ?? []) as ModelRow[]}
          columns={modelCols}
          emptyMessage="No model data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Remediation Action Breakdown</h2>
        <DataTable<ActionRow>
          rows={(actions.data ?? []) as ActionRow[]}
          columns={actionCols}
          emptyMessage="No action data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Unsigned Inspections</h2>
        <DataTable<UnsignedRow>
          rows={(unsigned.data ?? []) as UnsignedRow[]}
          columns={unsignedCols}
          emptyMessage="All inspections signed"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>
    </div>
  );
}
