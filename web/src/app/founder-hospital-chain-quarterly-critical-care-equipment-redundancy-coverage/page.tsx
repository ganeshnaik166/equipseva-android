import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Column<T> = { key: string; header: string; render: (r: T) => React.ReactNode };

type ChainRollup = { chain_name: string; branches: number; total_primary: number; total_backup: number; avg_ratio: number; gap_branches: number; critical_branches: number };
type CriticalBranch = { id?: string; chain_name: string; branch_code: string; city: string; equipment_category: string; redundancy_ratio: number; beds_served: number; failure_events_last_quarter: number };
type CategoryPosture = { equipment_category: string; branches: number; avg_ratio: number; total_required: number; total_backup: number; coverage_pct: number };
type Remediation = { id?: string; chain_name: string; branch_code: string; equipment_category: string; gap_units: number; est_cost_rupees: number; committed_close_date: string; status: string; risk_score: number };
type AmcUpsell = { chain_name: string; branches: number; total_amc_upsell_rupees: number; total_capex_rupees: number; avg_lead_days: number };
type CityHeat = { city: string; branches: number; total_beds: number; avg_ratio: number; critical_count: number; total_failures: number };
type Kpi = { total_branches: number; total_chains: number; compliant_branches: number; gap_branches: number; critical_branches: number; total_remediation_capex_rupees: number; total_amc_upsell_rupees: number; avg_redundancy_ratio: number };

function inr(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [kpiRes, chainRes, critRes, catRes, remRes, amcRes, cityRes] = await Promise.all([
    supabase.rpc('founder_r2895_kpi_summary'),
    supabase.rpc('founder_r2895_chain_rollup'),
    supabase.rpc('founder_r2895_critical_branches'),
    supabase.rpc('founder_r2895_category_posture'),
    supabase.rpc('founder_r2895_remediation_pipeline'),
    supabase.rpc('founder_r2895_amc_upsell_pipeline'),
    supabase.rpc('founder_r2895_city_heatmap'),
  ]);

  const kpi: Kpi | null = (kpiRes.data?.[0] ?? null) as Kpi | null;
  const chains: ChainRollup[] = (chainRes.data ?? []) as ChainRollup[];
  const criticals: CriticalBranch[] = (critRes.data ?? []) as CriticalBranch[];
  const categories: CategoryPosture[] = (catRes.data ?? []) as CategoryPosture[];
  const remediations: Remediation[] = (remRes.data ?? []) as Remediation[];
  const amcs: AmcUpsell[] = (amcRes.data ?? []) as AmcUpsell[];
  const cities: CityHeat[] = (cityRes.data ?? []) as CityHeat[];

  const chainCols: Column<ChainRollup>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'branches', header: 'Branches', render: (r) => r.branches },
    { key: 'total_primary', header: 'Primary', render: (r) => r.total_primary },
    { key: 'total_backup', header: 'Backup', render: (r) => r.total_backup },
    { key: 'avg_ratio', header: 'Avg ratio', render: (r) => Number(r.avg_ratio).toFixed(2) },
    { key: 'gap_branches', header: 'Gap', render: (r) => r.gap_branches },
    { key: 'critical_branches', header: 'Critical', render: (r) => r.critical_branches },
  ];

  const critCols: Column<CriticalBranch>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'branch_code', header: 'Branch', render: (r) => r.branch_code },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'equipment_category', header: 'Category', render: (r) => r.equipment_category },
    { key: 'redundancy_ratio', header: 'Ratio', render: (r) => Number(r.redundancy_ratio).toFixed(2) },
    { key: 'beds_served', header: 'Beds', render: (r) => r.beds_served },
    { key: 'failure_events_last_quarter', header: 'Failures Q', render: (r) => r.failure_events_last_quarter },
  ];

  const catCols: Column<CategoryPosture>[] = [
    { key: 'equipment_category', header: 'Category', render: (r) => r.equipment_category },
    { key: 'branches', header: 'Branches', render: (r) => r.branches },
    { key: 'avg_ratio', header: 'Avg ratio', render: (r) => Number(r.avg_ratio).toFixed(2) },
    { key: 'total_required', header: 'Required units', render: (r) => r.total_required },
    { key: 'total_backup', header: 'Backup units', render: (r) => r.total_backup },
    { key: 'coverage_pct', header: 'Coverage %', render: (r) => Number(r.coverage_pct ?? 0).toFixed(1) + '%' },
  ];

  const remCols: Column<Remediation>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'branch_code', header: 'Branch', render: (r) => r.branch_code },
    { key: 'equipment_category', header: 'Category', render: (r) => r.equipment_category },
    { key: 'gap_units', header: 'Gap units', render: (r) => r.gap_units },
    { key: 'est_cost_rupees', header: 'CAPEX', render: (r) => inr(r.est_cost_rupees) },
    { key: 'committed_close_date', header: 'Close by', render: (r) => r.committed_close_date },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'risk_score', header: 'Risk', render: (r) => r.risk_score },
  ];

  const amcCols: Column<AmcUpsell>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'branches', header: 'Branches in plan', render: (r) => r.branches },
    { key: 'total_amc_upsell_rupees', header: 'AMC upsell', render: (r) => inr(r.total_amc_upsell_rupees) },
    { key: 'total_capex_rupees', header: 'CAPEX exposure', render: (r) => inr(r.total_capex_rupees) },
    { key: 'avg_lead_days', header: 'Avg lead (d)', render: (r) => Number(r.avg_lead_days).toFixed(1) },
  ];

  const cityCols: Column<CityHeat>[] = [
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'branches', header: 'Branches', render: (r) => r.branches },
    { key: 'total_beds', header: 'Beds', render: (r) => r.total_beds },
    { key: 'avg_ratio', header: 'Avg ratio', render: (r) => Number(r.avg_ratio).toFixed(2) },
    { key: 'critical_count', header: 'Critical', render: (r) => r.critical_count },
    { key: 'total_failures', header: 'Failures', render: (r) => r.total_failures },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'ui-sans-serif, system-ui' }}>
      <header style={{ marginBottom: 20 }}>
        <h1 style={{ fontSize: 26, fontWeight: 700 }}>Hospital Chain Quarterly Critical-Care Equipment Redundancy Coverage</h1>
        <p style={{ color: '#555', marginTop: 6 }}>
          Multi-branch rollup of ventilator, dialysis, defib &amp; monitor redundancy posture across chain partners.
          Backup-to-primary ratio &gt;= 0.40 is the floor; anything &lt; 0.35 escalates to founder ops.
        </p>
      </header>

      {kpi && (
        <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0,1fr))', gap: 12, marginBottom: 24 }}>
          <KpiCard label="Branches" value={String(kpi.total_branches)} />
          <KpiCard label="Chains" value={String(kpi.total_chains)} />
          <KpiCard label="Compliant" value={String(kpi.compliant_branches)} />
          <KpiCard label="Critical gaps" value={String(kpi.critical_branches)} />
          <KpiCard label="Gap branches" value={String(kpi.gap_branches)} />
          <KpiCard label="Avg ratio" value={Number(kpi.avg_redundancy_ratio).toFixed(2)} />
          <KpiCard label="CAPEX exposure" value={inr(kpi.total_remediation_capex_rupees)} />
          <KpiCard label="AMC upsell pipe" value={inr(kpi.total_amc_upsell_rupees)} />
        </section>
      )}

      <Section title="Chain rollup">
        <DataTable rows={chains} columns={chainCols} emptyMessage="No chains" rowKey={(r, i) => String((r as { chain_name?: string }).chain_name ?? i)} />
      </Section>

      <Section title="Critical-gap branches (ratio < 0.35)">
        <DataTable rows={criticals} columns={critCols} emptyMessage="No critical branches" rowKey={(r, i) => String((r as { id?: string; branch_code?: string }).id ?? (r as { branch_code?: string }).branch_code ?? i)} />
      </Section>

      <Section title="Category posture (coverage % ascending)">
        <DataTable rows={categories} columns={catCols} emptyMessage="No data" rowKey={(r, i) => String((r as { equipment_category?: string }).equipment_category ?? i)} />
      </Section>

      <Section title="Remediation pipeline (risk-sorted)">
        <DataTable rows={remediations} columns={remCols} emptyMessage="No remediations" rowKey={(r, i) => String((r as { id?: string; branch_code?: string }).id ?? (r as { branch_code?: string }).branch_code ?? i)} />
      </Section>

      <Section title="AMC upsell pipeline by chain">
        <DataTable rows={amcs} columns={amcCols} emptyMessage="No AMC pipe" rowKey={(r, i) => String((r as { chain_name?: string }).chain_name ?? i)} />
      </Section>

      <Section title="City heatmap">
        <DataTable rows={cities} columns={cityCols} emptyMessage="No cities" rowKey={(r, i) => String((r as { city?: string }).city ?? i)} />
      </Section>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 10, padding: 14, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#6b7280' }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 17, fontWeight: 600, marginBottom: 8 }}>{title}</h2>
      {children}
    </section>
  );
}
