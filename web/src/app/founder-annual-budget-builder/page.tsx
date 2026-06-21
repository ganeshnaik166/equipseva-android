import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtR(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return 'Rs ' + v.toLocaleString('en-IN');
}

export default async function FounderAnnualBudgetBuilderPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpi: any = {};
  let years: any[] = [];
  let rollup: any[] = [];
  let recent: any[] = [];
  let variances: any[] = [];

  try {
    const r = await sb.rpc('founder_budget_kpis');
    kpi = (r.data && r.data[0]) || {};
  } catch {}
  try {
    const r = await sb.rpc('founder_budget_list_years');
    years = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_budget_department_rollup');
    rollup = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_budget_lines_recent');
    recent = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_budget_top_variances');
    variances = r.data || [];
  } catch {}

  const cards: Kpi[] = [
    { label: 'Total Budgets', value: String(kpi.total_budgets ?? 0) },
    { label: 'Current Year', value: String(kpi.current_year ?? '—') },
    { label: 'Current Proposed', value: fmtR(kpi.current_proposed) },
    { label: 'Current Approved', value: fmtR(kpi.current_approved) },
    { label: 'Current Actual', value: fmtR(kpi.current_actual) },
    { label: 'Current Variance', value: fmtR(kpi.current_variance) },
    { label: 'Locked Budgets', value: String(kpi.locked_budgets ?? 0) },
    { label: 'Draft Budgets', value: String(kpi.draft_budgets ?? 0) },
    { label: 'Eng Approved', value: fmtR(kpi.eng_approved) },
    { label: 'Sales Approved', value: fmtR(kpi.sales_approved) },
    { label: 'Ops Approved', value: fmtR(kpi.ops_approved) },
    { label: 'Marketing Approved', value: fmtR(kpi.marketing_approved) },
    { label: 'G and A Approved', value: fmtR(kpi.g_and_a_approved) },
    { label: 'Line Items', value: String(kpi.line_items_total ?? 0) },
    { label: 'Over Budget Lines', value: String(kpi.over_budget_lines ?? 0) },
    { label: 'Under Budget Lines', value: String(kpi.under_budget_lines ?? 0) },
  ];

  const yearCols: Column<any>[] = [
    { key: 'fiscal_year', header: 'Year', render: (r: any) => r.fiscal_year ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'total_proposed_rupees', header: 'Proposed', render: (r: any) => fmtR(r.total_proposed_rupees) },
    { key: 'total_approved_rupees', header: 'Approved', render: (r: any) => fmtR(r.total_approved_rupees) },
    { key: 'locked_at', header: 'Locked At', render: (r: any) => r.locked_at ? new Date(r.locked_at).toLocaleString() : '—' },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleDateString() : '—' },
  ];

  const rollupCols: Column<any>[] = [
    { key: 'department', header: 'Department', render: (r: any) => r.department ?? '—' },
    { key: 'line_count', header: 'Lines', render: (r: any) => r.line_count ?? 0 },
    { key: 'proposed_rupees', header: 'Proposed', render: (r: any) => fmtR(r.proposed_rupees) },
    { key: 'approved_rupees', header: 'Approved', render: (r: any) => fmtR(r.approved_rupees) },
    { key: 'actual_spend_rupees', header: 'Actual', render: (r: any) => fmtR(r.actual_spend_rupees) },
    { key: 'variance_rupees', header: 'Variance', render: (r: any) => fmtR(r.variance_rupees) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'fiscal_year', header: 'Year', render: (r: any) => r.fiscal_year ?? '—' },
    { key: 'department', header: 'Dept', render: (r: any) => r.department ?? '—' },
    { key: 'line_item', header: 'Line Item', render: (r: any) => r.line_item ?? '—' },
    { key: 'category', header: 'Category', render: (r: any) => r.category ?? '—' },
    { key: 'proposed_rupees', header: 'Proposed', render: (r: any) => fmtR(r.proposed_rupees) },
    { key: 'approved_rupees', header: 'Approved', render: (r: any) => fmtR(r.approved_rupees) },
    { key: 'actual_spend_rupees', header: 'Actual', render: (r: any) => fmtR(r.actual_spend_rupees) },
    { key: 'variance_rupees', header: 'Variance', render: (r: any) => fmtR(r.variance_rupees) },
    { key: 'updated_at', header: 'Updated', render: (r: any) => r.updated_at ? new Date(r.updated_at).toLocaleString() : '—' },
  ];

  const varCols: Column<any>[] = [
    { key: 'fiscal_year', header: 'Year', render: (r: any) => r.fiscal_year ?? '—' },
    { key: 'department', header: 'Dept', render: (r: any) => r.department ?? '—' },
    { key: 'line_item', header: 'Line Item', render: (r: any) => r.line_item ?? '—' },
    { key: 'approved_rupees', header: 'Approved', render: (r: any) => fmtR(r.approved_rupees) },
    { key: 'actual_spend_rupees', header: 'Actual', render: (r: any) => fmtR(r.actual_spend_rupees) },
    { key: 'variance_rupees', header: 'Variance', render: (r: any) => fmtR(r.variance_rupees) },
    { key: 'variance_pct', header: 'Variance %', render: (r: any) => (r.variance_pct ?? 0) + '%' },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder Annual Budget Builder</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Departmental budgets for next fiscal year. Proposed vs approved per line item. Founder lock and variance tracking.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {cards.map((c, i) => (
          <div key={i} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 11, textTransform: 'uppercase', color: '#6b7280' }}>{c.label}</div>
            <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{c.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Budget Years</h2>
        <DataTable<any> rows={years} columns={yearCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Department Rollup (Current Year)</h2>
        <DataTable<any> rows={rollup} columns={rollupCols} rowKey={(r: any) => r.department} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Variances</h2>
        <DataTable<any> rows={variances} columns={varCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Line Items</h2>
        <DataTable<any> rows={recent} columns={recentCols} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
