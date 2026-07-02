import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type MonthlySummary = { audit_month: string; total_audits: number; passed_count: number; flagged_count: number; failed_count: number; pass_rate_pct: number | null };
type EngineerRow = { engineer_code: string; audits_completed: number; flagged_or_failed: number; avg_seal_kpa: number | null; avg_leak_rate: number | null };
type MaterialRow = { gasket_material: string; total_audits: number; failure_count: number; avg_age_months: number | null; avg_leak_rate: number | null };
type FlaggedRow = { hospital_code: string; steriliser_asset_tag: string; audit_month: string; audit_status: string; leak_rate_ml_per_min: number; next_audit_due: string | null };
type PipelineRow = { order_status: string; order_count: number; total_value_rupees: number | null; avg_warranty_months: number | null };
type BrandRow = { part_brand: string; order_count: number; units_total: number; total_spend_rupees: number | null; avg_unit_cost: number | null };
type OverdueRow = { audit_visit_ref: string; engineer_code: string; hospital_code: string; part_sku: string; order_status: string; ordered_at: string | null; days_since_order: number };
type TierRow = { approval_tier: string; order_count: number; total_value_rupees: number | null; pct_of_orders: number | null };

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [summary, leaderboard, materialRisk, flagged, pipeline, brandSpend, overdue, tierMix] = await Promise.all([
    sb.rpc('fn_r3062_monthly_audit_summary'),
    sb.rpc('fn_r3062_engineer_leaderboard'),
    sb.rpc('fn_r3062_gasket_material_risk'),
    sb.rpc('fn_r3062_hospitals_flagged'),
    sb.rpc('fn_r3062_replacement_pipeline'),
    sb.rpc('fn_r3062_brand_spend'),
    sb.rpc('fn_r3062_overdue_replacements'),
    sb.rpc('fn_r3062_approval_tier_mix'),
  ]);

  const summaryRows: MonthlySummary[] = (summary.data ?? []) as MonthlySummary[];
  const engineerRows: EngineerRow[] = (leaderboard.data ?? []) as EngineerRow[];
  const materialRows: MaterialRow[] = (materialRisk.data ?? []) as MaterialRow[];
  const flaggedRows: FlaggedRow[] = (flagged.data ?? []) as FlaggedRow[];
  const pipelineRows: PipelineRow[] = (pipeline.data ?? []) as PipelineRow[];
  const brandRows: BrandRow[] = (brandSpend.data ?? []) as BrandRow[];
  const overdueRows: OverdueRow[] = (overdue.data ?? []) as OverdueRow[];
  const tierRows: TierRow[] = (tierMix.data ?? []) as TierRow[];

  const summaryCols: Column<MonthlySummary>[] = [
    { header: 'Month', accessor: (r) => r.audit_month },
    { header: 'Audits', accessor: (r) => r.total_audits },
    { header: 'Passed', accessor: (r) => r.passed_count },
    { header: 'Flagged', accessor: (r) => r.flagged_count },
    { header: 'Failed', accessor: (r) => r.failed_count },
    { header: 'Pass %', accessor: (r) => r.pass_rate_pct ?? '-' },
  ];

  const engineerCols: Column<EngineerRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_code },
    { header: 'Audits', accessor: (r) => r.audits_completed },
    { header: 'Flagged/Failed', accessor: (r) => r.flagged_or_failed },
    { header: 'Avg Seal kPa', accessor: (r) => r.avg_seal_kpa ?? '-' },
    { header: 'Avg Leak ml/min', accessor: (r) => r.avg_leak_rate ?? '-' },
  ];

  const materialCols: Column<MaterialRow>[] = [
    { header: 'Material', accessor: (r) => r.gasket_material },
    { header: 'Audits', accessor: (r) => r.total_audits },
    { header: 'Failures', accessor: (r) => r.failure_count },
    { header: 'Avg Age (mo)', accessor: (r) => r.avg_age_months ?? '-' },
    { header: 'Avg Leak', accessor: (r) => r.avg_leak_rate ?? '-' },
  ];

  const flaggedCols: Column<FlaggedRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_code },
    { header: 'Asset', accessor: (r) => r.steriliser_asset_tag },
    { header: 'Month', accessor: (r) => r.audit_month },
    { header: 'Status', accessor: (r) => r.audit_status },
    { header: 'Leak ml/min', accessor: (r) => r.leak_rate_ml_per_min },
    { header: 'Next Audit', accessor: (r) => r.next_audit_due ?? '-' },
  ];

  const pipelineCols: Column<PipelineRow>[] = [
    { header: 'Status', accessor: (r) => r.order_status },
    { header: 'Orders', accessor: (r) => r.order_count },
    { header: 'Value (Rs)', accessor: (r) => r.total_value_rupees ?? '-' },
    { header: 'Avg Warranty (mo)', accessor: (r) => r.avg_warranty_months ?? '-' },
  ];

  const brandCols: Column<BrandRow>[] = [
    { header: 'Brand', accessor: (r) => r.part_brand },
    { header: 'Orders', accessor: (r) => r.order_count },
    { header: 'Units', accessor: (r) => r.units_total },
    { header: 'Spend (Rs)', accessor: (r) => r.total_spend_rupees ?? '-' },
    { header: 'Avg Unit Cost', accessor: (r) => r.avg_unit_cost ?? '-' },
  ];

  const overdueCols: Column<OverdueRow>[] = [
    { header: 'Audit Ref', accessor: (r) => r.audit_visit_ref },
    { header: 'Engineer', accessor: (r) => r.engineer_code },
    { header: 'Hospital', accessor: (r) => r.hospital_code },
    { header: 'Part', accessor: (r) => r.part_sku },
    { header: 'Status', accessor: (r) => r.order_status },
    { header: 'Ordered', accessor: (r) => r.ordered_at ?? '-' },
    { header: 'Days Open', accessor: (r) => r.days_since_order },
  ];

  const tierCols: Column<TierRow>[] = [
    { header: 'Approval Tier', accessor: (r) => r.approval_tier },
    { header: 'Orders', accessor: (r) => r.order_count },
    { header: 'Value (Rs)', accessor: (r) => r.total_value_rupees ?? '-' },
    { header: '% of Orders', accessor: (r) => r.pct_of_orders ?? '-' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly Steriliser Door Gasket & Pressure Seal Audit</h1>
        <p className="text-sm text-gray-600">Round r3062 · Batch 440 milestone · Founder console</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Audit Summary</h2>
        <DataTable<MonthlySummary>
          rows={summaryRows}
          columns={summaryCols}
          emptyMessage="No audit months recorded"
          rowKey={(r, i) => String(r.audit_month ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Leaderboard</h2>
        <DataTable<EngineerRow>
          rows={engineerRows}
          columns={engineerCols}
          emptyMessage="No engineers audited"
          rowKey={(r, i) => String(r.engineer_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Gasket Material Risk</h2>
        <DataTable<MaterialRow>
          rows={materialRows}
          columns={materialCols}
          emptyMessage="No material data"
          rowKey={(r, i) => String(r.gasket_material ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Hospitals With Flagged Audits</h2>
        <DataTable<FlaggedRow>
          rows={flaggedRows}
          columns={flaggedCols}
          emptyMessage="No flagged audits"
          rowKey={(r, i) => String(r.steriliser_asset_tag ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Replacement Pipeline</h2>
        <DataTable<PipelineRow>
          rows={pipelineRows}
          columns={pipelineCols}
          emptyMessage="No orders in pipeline"
          rowKey={(r, i) => String(r.order_status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Brand Spend Breakdown</h2>
        <DataTable<BrandRow>
          rows={brandRows}
          columns={brandCols}
          emptyMessage="No brand spend"
          rowKey={(r, i) => String(r.part_brand ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Overdue Replacements (approved &gt;= drafted, not installed)</h2>
        <DataTable<OverdueRow>
          rows={overdueRows}
          columns={overdueCols}
          emptyMessage="No overdue replacements"
          rowKey={(r, i) => String(r.audit_visit_ref ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Approval Tier Mix</h2>
        <DataTable<TierRow>
          rows={tierRows}
          columns={tierCols}
          emptyMessage="No approval tiers seen"
          rowKey={(r, i) => String(r.approval_tier ?? i)}
        />
      </section>
    </main>
  );
}
