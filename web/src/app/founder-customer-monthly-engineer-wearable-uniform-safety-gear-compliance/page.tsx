import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ComplianceSummary = {
  total_checks: number;
  flagged_checks: number;
  avg_compliance_score: number;
  perfect_scores: number;
  unique_cities: number;
};

type CityRow = {
  city: string;
  checks: number;
  flagged: number;
  avg_score: number;
};

type FlaggedRow = {
  id: string;
  city: string;
  check_month: string;
  compliance_score: number;
  customer_feedback: string | null;
};

type GearSummary = {
  total_items: number;
  replacement_due_count: number;
  total_cost_rupees: number;
  unique_gear_types: number;
};

type GearDueRow = {
  id: string;
  gear_type: string;
  city: string;
  condition_grade: string;
  cost_rupees: number;
  supplier_name: string | null;
};

type GearTypeRow = {
  gear_type: string;
  units: number;
  total_cost: number;
  due_count: number;
};

type RecentCheckRow = {
  id: string;
  check_month: string;
  city: string;
  compliance_score: number;
  total_items_passed: number;
  flagged: boolean;
};

type SupplierRow = {
  supplier_name: string;
  units: number;
  total_spend_rupees: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    summaryRes,
    byCityRes,
    flaggedRes,
    gearSummaryRes,
    gearDueRes,
    gearByTypeRes,
    recentRes,
    supplierRes,
  ] = await Promise.all([
    supabase.rpc('rpc_r2908_compliance_summary'),
    supabase.rpc('rpc_r2908_compliance_by_city'),
    supabase.rpc('rpc_r2908_flagged_checks'),
    supabase.rpc('rpc_r2908_gear_inventory_summary'),
    supabase.rpc('rpc_r2908_gear_replacement_due'),
    supabase.rpc('rpc_r2908_gear_by_type'),
    supabase.rpc('rpc_r2908_recent_checks'),
    supabase.rpc('rpc_r2908_supplier_spend'),
  ]);

  const summary: ComplianceSummary | null = (summaryRes.data?.[0] as ComplianceSummary) ?? null;
  const byCity: CityRow[] = (byCityRes.data as CityRow[]) ?? [];
  const flagged: FlaggedRow[] = (flaggedRes.data as FlaggedRow[]) ?? [];
  const gearSummary: GearSummary | null = (gearSummaryRes.data?.[0] as GearSummary) ?? null;
  const gearDue: GearDueRow[] = (gearDueRes.data as GearDueRow[]) ?? [];
  const gearByType: GearTypeRow[] = (gearByTypeRes.data as GearTypeRow[]) ?? [];
  const recent: RecentCheckRow[] = (recentRes.data as RecentCheckRow[]) ?? [];
  const suppliers: SupplierRow[] = (supplierRes.data as SupplierRow[]) ?? [];

  const cityColumns: Column<CityRow>[] = [
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'checks', header: 'Checks', render: (r) => r.checks },
    { key: 'flagged', header: 'Flagged', render: (r) => r.flagged },
    { key: 'avg_score', header: 'Avg Score', render: (r) => `${r.avg_score}%` },
  ];

  const flaggedColumns: Column<FlaggedRow>[] = [
    { key: 'check_month', header: 'Month', render: (r) => r.check_month },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'compliance_score', header: 'Score', render: (r) => `${r.compliance_score}%` },
    { key: 'customer_feedback', header: 'Customer Feedback', render: (r) => r.customer_feedback ?? '-' },
  ];

  const gearDueColumns: Column<GearDueRow>[] = [
    { key: 'gear_type', header: 'Gear', render: (r) => r.gear_type },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'condition_grade', header: 'Condition', render: (r) => r.condition_grade },
    { key: 'cost_rupees', header: 'Replacement Cost', render: (r) => `₹${r.cost_rupees.toLocaleString('en-IN')}` },
    { key: 'supplier_name', header: 'Supplier', render: (r) => r.supplier_name ?? '-' },
  ];

  const gearTypeColumns: Column<GearTypeRow>[] = [
    { key: 'gear_type', header: 'Gear Type', render: (r) => r.gear_type },
    { key: 'units', header: 'Units', render: (r) => r.units },
    { key: 'total_cost', header: 'Total Cost', render: (r) => `₹${r.total_cost.toLocaleString('en-IN')}` },
    { key: 'due_count', header: 'Replacement Due', render: (r) => r.due_count },
  ];

  const recentColumns: Column<RecentCheckRow>[] = [
    { key: 'check_month', header: 'Month', render: (r) => r.check_month },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'compliance_score', header: 'Score', render: (r) => `${r.compliance_score}%` },
    { key: 'total_items_passed', header: 'Items Passed', render: (r) => `${r.total_items_passed} / 8` },
    { key: 'flagged', header: 'Flagged', render: (r) => (r.flagged ? 'Yes' : 'No') },
  ];

  const supplierColumns: Column<SupplierRow>[] = [
    { key: 'supplier_name', header: 'Supplier', render: (r) => r.supplier_name },
    { key: 'units', header: 'Units Supplied', render: (r) => r.units },
    { key: 'total_spend_rupees', header: 'Total Spend', render: (r) => `₹${r.total_spend_rupees.toLocaleString('en-IN')}` },
  ];

  return (
    <main className="mx-auto max-w-7xl px-6 py-10">
      <header className="mb-8">
        <h1 className="text-3xl font-semibold tracking-tight">
          Monthly Engineer Wearable-Uniform & Safety-Gear Compliance
        </h1>
        <p className="mt-2 text-sm text-gray-600">
          Customer-facing audit of engineer uniform cleanliness, PPE adherence, ID badge visibility &
          safety-gear inventory across every monthly site visit. Flagged checks & replacement-due gear surfaced
          for founder action.
        </p>
      </header>

      <section className="mb-10 grid grid-cols-2 gap-4 md:grid-cols-5">
        <KPI label="Total Checks" value={summary?.total_checks ?? 0} />
        <KPI label="Flagged" value={summary?.flagged_checks ?? 0} tone="warn" />
        <KPI label="Avg Score" value={`${summary?.avg_compliance_score ?? 0}%`} />
        <KPI label="Perfect 100%" value={summary?.perfect_scores ?? 0} tone="good" />
        <KPI label="Cities" value={summary?.unique_cities ?? 0} />
      </section>

      <section className="mb-10 grid grid-cols-2 gap-4 md:grid-cols-4">
        <KPI label="Gear Items" value={gearSummary?.total_items ?? 0} />
        <KPI label="Replacement Due" value={gearSummary?.replacement_due_count ?? 0} tone="warn" />
        <KPI
          label="Inventory Spend"
          value={`₹${(gearSummary?.total_cost_rupees ?? 0).toLocaleString('en-IN')}`}
        />
        <KPI label="Gear Types" value={gearSummary?.unique_gear_types ?? 0} />
      </section>

      <Section title="Compliance by City">
        <DataTable
          rows={byCity}
          columns={cityColumns}
          emptyMessage="No city compliance data."
          rowKey={(r, i) => String((r as CityRow).city ?? i)}
        />
      </Section>

      <Section title="Flagged Checks (score < 100%)">
        <DataTable
          rows={flagged}
          columns={flaggedColumns}
          emptyMessage="No flagged checks — all engineers compliant."
          rowKey={(r, i) => String((r as FlaggedRow).id ?? i)}
        />
      </Section>

      <Section title="Recent Compliance Checks">
        <DataTable
          rows={recent}
          columns={recentColumns}
          emptyMessage="No recent checks."
          rowKey={(r, i) => String((r as RecentCheckRow).id ?? i)}
        />
      </Section>

      <Section title="Gear Inventory by Type">
        <DataTable
          rows={gearByType}
          columns={gearTypeColumns}
          emptyMessage="No gear inventory."
          rowKey={(r, i) => String((r as GearTypeRow).gear_type ?? i)}
        />
      </Section>

      <Section title="Gear Replacement Due">
        <DataTable
          rows={gearDue}
          columns={gearDueColumns}
          emptyMessage="No items pending replacement."
          rowKey={(r, i) => String((r as GearDueRow).id ?? i)}
        />
      </Section>

      <Section title="Supplier Spend">
        <DataTable
          rows={suppliers}
          columns={supplierColumns}
          emptyMessage="No supplier spend data."
          rowKey={(r, i) => String((r as SupplierRow).supplier_name ?? i)}
        />
      </Section>
    </main>
  );
}

function KPI({
  label,
  value,
  tone,
}: {
  label: string;
  value: string | number;
  tone?: 'good' | 'warn';
}) {
  const toneClass =
    tone === 'good'
      ? 'text-emerald-700'
      : tone === 'warn'
        ? 'text-amber-700'
        : 'text-gray-900';
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className={`mt-1 text-2xl font-semibold ${toneClass}`}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="mb-10">
      <h2 className="mb-3 text-lg font-semibold text-gray-900">{title}</h2>
      {children}
    </section>
  );
}
