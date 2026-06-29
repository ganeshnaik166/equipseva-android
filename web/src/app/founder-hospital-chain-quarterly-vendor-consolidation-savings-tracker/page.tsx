import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ChainRow = { chain_name: string; branches: number; vendors_before: number; vendors_after: number; total_savings: number; avg_pct: number };
type QuarterRow = { quarter_label: string; chains: number; total_branches: number; total_savings: number; avg_savings_pct: number };
type CategoryRow = { vendor_category: string; lines: number; monthly_savings: number; annualized_savings: number };
type StatusRow = { status: string; quarters: number; savings: number };
type MigrationRow = { chain_name: string; branch_name: string; vendor_category: string; vendor_name: string; monthly_savings: number; contract_status: string };
type BranchRow = { chain_name: string; branch_name: string; lines: number; monthly_savings: number };
type Kpi = { total_chains: number; total_branches: number; total_savings_realized: number; total_savings_planned: number; avg_pct: number; vendors_eliminated: number };

function inr(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [chains, quarters, categories, statuses, migrations, branches, kpi] = await Promise.all([
    supabase.rpc('rpc_r2899_chain_rollup'),
    supabase.rpc('rpc_r2899_quarterly_summary'),
    supabase.rpc('rpc_r2899_top_categories'),
    supabase.rpc('rpc_r2899_status_mix'),
    supabase.rpc('rpc_r2899_migrations_in_flight'),
    supabase.rpc('rpc_r2899_top_branches'),
    supabase.rpc('rpc_r2899_kpi_snapshot'),
  ]);

  const chainRows = (chains.data ?? []) as ChainRow[];
  const quarterRows = (quarters.data ?? []) as QuarterRow[];
  const categoryRows = (categories.data ?? []) as CategoryRow[];
  const statusRows = (statuses.data ?? []) as StatusRow[];
  const migrationRows = (migrations.data ?? []) as MigrationRow[];
  const branchRows = (branches.data ?? []) as BranchRow[];
  const k = ((kpi.data ?? [])[0] ?? {}) as Kpi;

  const chainCols: Column<ChainRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'branches', header: 'Branches', render: (r) => r.branches },
    { key: 'vendors_before', header: 'Vendors Before', render: (r) => r.vendors_before },
    { key: 'vendors_after', header: 'Vendors After', render: (r) => r.vendors_after },
    { key: 'total_savings', header: 'Total Savings', render: (r) => inr(r.total_savings) },
    { key: 'avg_pct', header: 'Avg %', render: (r) => `${r.avg_pct}%` },
  ];

  const quarterCols: Column<QuarterRow>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r) => r.quarter_label },
    { key: 'chains', header: 'Chains', render: (r) => r.chains },
    { key: 'total_branches', header: 'Branches', render: (r) => r.total_branches },
    { key: 'total_savings', header: 'Savings', render: (r) => inr(r.total_savings) },
    { key: 'avg_savings_pct', header: 'Avg %', render: (r) => `${r.avg_savings_pct}%` },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'vendor_category', header: 'Category', render: (r) => r.vendor_category },
    { key: 'lines', header: 'Lines', render: (r) => r.lines },
    { key: 'monthly_savings', header: 'Monthly Savings', render: (r) => inr(r.monthly_savings) },
    { key: 'annualized_savings', header: 'Annualized', render: (r) => inr(r.annualized_savings) },
  ];

  const statusCols: Column<StatusRow>[] = [
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'quarters', header: 'Quarters', render: (r) => r.quarters },
    { key: 'savings', header: 'Savings', render: (r) => inr(r.savings) },
  ];

  const migrationCols: Column<MigrationRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'branch_name', header: 'Branch', render: (r) => r.branch_name },
    { key: 'vendor_category', header: 'Category', render: (r) => r.vendor_category },
    { key: 'vendor_name', header: 'Vendor', render: (r) => r.vendor_name },
    { key: 'monthly_savings', header: 'Monthly Savings', render: (r) => inr(r.monthly_savings) },
    { key: 'contract_status', header: 'Status', render: (r) => r.contract_status },
  ];

  const branchCols: Column<BranchRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'branch_name', header: 'Branch', render: (r) => r.branch_name },
    { key: 'lines', header: 'Lines', render: (r) => r.lines },
    { key: 'monthly_savings', header: 'Monthly Savings', render: (r) => inr(r.monthly_savings) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>Hospital Chain Quarterly Vendor Consolidation Savings Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>Multi-branch rollup of vendor consolidation quarters & realized savings — founder view.</p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(180px,1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ border: '1px solid #e5e7eb', padding: 16, borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Chains</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{k.total_chains ?? 0}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', padding: 16, borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Branches</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{k.total_branches ?? 0}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', padding: 16, borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Savings Realized</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{inr(k.total_savings_realized)}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', padding: 16, borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Savings Planned</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{inr(k.total_savings_planned)}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', padding: 16, borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Avg Savings %</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{k.avg_pct ?? 0}%</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', padding: 16, borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Vendors Eliminated</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{k.vendors_eliminated ?? 0}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Chain Rollup</h2>
        <DataTable rows={chainRows} columns={chainCols} emptyMessage="No chains" rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.chain_name}-${i}`)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Quarterly Summary</h2>
        <DataTable rows={quarterRows} columns={quarterCols} emptyMessage="No quarters" rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.quarter_label}-${i}`)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Vendor Categories</h2>
        <DataTable rows={categoryRows} columns={categoryCols} emptyMessage="No categories" rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.vendor_category}-${i}`)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Status Mix</h2>
        <DataTable rows={statusRows} columns={statusCols} emptyMessage="No statuses" rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.status}-${i}`)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Migrations In Flight</h2>
        <DataTable rows={migrationRows} columns={migrationCols} emptyMessage="No active migrations" rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.chain_name}-${r.branch_name}-${i}`)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Branches by Savings</h2>
        <DataTable rows={branchRows} columns={branchCols} emptyMessage="No branches" rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.chain_name}-${r.branch_name}-${i}`)} />
      </section>
    </main>
  );
}
