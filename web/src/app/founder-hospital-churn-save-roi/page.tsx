import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function rupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return "-";
  return new Intl.NumberFormat('en-IN', { maximumFractionDigits: 0 }).format(Number(n));
}

function num(n: number | null | undefined, d: number = 2): string {
  if (n === null || n === undefined) return "-";
  return Number(n).toFixed(d);
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let perAction: any[] = [];
  let topSaves: any[] = [];
  let worstSaves: any[] = [];
  let recent: any[] = [];

  try {
    const { data } = await sb.rpc('founder_churn_save_roi_kpis');
    kpis = (data && data[0]) || {};
  } catch {
    kpis = {};
  }
  try {
    const { data } = await sb.rpc('founder_churn_save_roi_per_action_rank');
    perAction = data || [];
  } catch {
    perAction = [];
  }
  try {
    const { data } = await sb.rpc('founder_churn_save_roi_top_saves', { p_limit: 25 });
    topSaves = data || [];
  } catch {
    topSaves = [];
  }
  try {
    const { data } = await sb.rpc('founder_churn_save_roi_worst_saves', { p_limit: 25 });
    worstSaves = data || [];
  } catch {
    worstSaves = [];
  }
  try {
    const { data } = await sb.rpc('founder_churn_save_roi_recent', { p_limit: 40 });
    recent = data || [];
  } catch {
    recent = [];
  }

  const cards: Kpi[] = [
    { label: 'Total saves', value: String(kpis.total_saves ?? "-") },
    { label: 'Retained', value: String(kpis.retained_count ?? "-") },
    { label: 'Churned', value: String(kpis.churned_count ?? "-") },
    { label: 'Pending', value: String(kpis.pending_count ?? "-") },
    { label: 'Total cost (Rs)', value: rupees(kpis.total_cost_rupees) },
    { label: 'Revenue saved (Rs)', value: rupees(kpis.total_revenue_saved_rupees) },
    { label: 'Blended ROI', value: num(kpis.blended_roi) + 'x' },
    { label: 'Median ROI', value: num(kpis.median_roi) + 'x' },
    { label: 'Top ROI', value: num(kpis.top_roi) + 'x' },
    { label: 'Worst ROI', value: num(kpis.worst_roi) + 'x' },
    { label: 'Saves 30d', value: String(kpis.saves_last_30d ?? "-") },
    { label: 'Saves 90d', value: String(kpis.saves_last_90d ?? "-") },
    { label: 'Retention rate %', value: num(kpis.retained_rate_pct, 1) },
    { label: 'Cost per retained', value: rupees(kpis.cost_per_retained_rupees) },
    { label: 'Unique hospitals', value: String(kpis.unique_hospitals ?? "-") },
    { label: 'Best action', value: String(kpis.best_action ?? "-") },
  ];

  const rankCols: Column<any>[] = [
    { key: 'rank', header: 'Rank', render: (r: any) => r.rank ?? "-" },
    { key: 'save_action', header: 'Action', render: (r: any) => r.save_action ?? "-" },
    { key: 'total_saves', header: 'Saves', render: (r: any) => r.total_saves ?? "-" },
    { key: 'retained_count', header: 'Retained', render: (r: any) => r.retained_count ?? "-" },
    { key: 'churned_count', header: 'Churned', render: (r: any) => r.churned_count ?? "-" },
    { key: 'total_cost_rupees', header: 'Cost Rs', render: (r: any) => rupees(r.total_cost_rupees) },
    { key: 'total_revenue_saved_rupees', header: 'Revenue Rs', render: (r: any) => rupees(r.total_revenue_saved_rupees) },
    { key: 'blended_roi', header: 'Blended ROI', render: (r: any) => num(r.blended_roi) + 'x' },
    { key: 'median_roi', header: 'Median ROI', render: (r: any) => num(r.median_roi) + 'x' },
    { key: 'target_roi', header: 'Target', render: (r: any) => num(r.target_roi) + 'x' },
    { key: 'vs_target_pct', header: 'vs Target %', render: (r: any) => num(r.vs_target_pct, 1) },
  ];

  const topCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? "-" },
    { key: 'save_action', header: 'Action', render: (r: any) => r.save_action ?? "-" },
    { key: 'cost_of_save_rupees', header: 'Cost Rs', render: (r: any) => rupees(r.cost_of_save_rupees) },
    { key: 'revenue_saved_12mo_rupees', header: 'Revenue Rs', render: (r: any) => rupees(r.revenue_saved_12mo_rupees) },
    { key: 'roi_ratio', header: 'ROI', render: (r: any) => num(r.roi_ratio) + 'x' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? "-" },
    { key: 'action_taken_at', header: 'When', render: (r: any) => r.action_taken_at ? new Date(r.action_taken_at).toLocaleDateString() : "-" },
  ];

  const worstCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? "-" },
    { key: 'save_action', header: 'Action', render: (r: any) => r.save_action ?? "-" },
    { key: 'cost_of_save_rupees', header: 'Cost Rs', render: (r: any) => rupees(r.cost_of_save_rupees) },
    { key: 'revenue_saved_12mo_rupees', header: 'Revenue Rs', render: (r: any) => rupees(r.revenue_saved_12mo_rupees) },
    { key: 'roi_ratio', header: 'ROI', render: (r: any) => num(r.roi_ratio) + 'x' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? "-" },
  ];

  const recentCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? "-" },
    { key: 'save_action', header: 'Action', render: (r: any) => r.save_action ?? "-" },
    { key: 'action_taken_at', header: 'Taken', render: (r: any) => r.action_taken_at ? new Date(r.action_taken_at).toLocaleString() : "-" },
    { key: 'days_since_action', header: 'Days ago', render: (r: any) => num(r.days_since_action, 1) },
    { key: 'cost_of_save_rupees', header: 'Cost Rs', render: (r: any) => rupees(r.cost_of_save_rupees) },
    { key: 'revenue_saved_12mo_rupees', header: 'Revenue Rs', render: (r: any) => rupees(r.revenue_saved_12mo_rupees) },
    { key: 'roi_ratio', header: 'ROI', render: (r: any) => num(r.roi_ratio) + 'x' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? "-" },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Hospital Churn-Save Dollar ROI</h1>
      <p style={{ color: '#666', marginBottom: 16, fontSize: 13 }}>
        Extends r1563 churn-save with explicit ROI math. Revenue saved (12 mo forward) divided by cost of save action. Per-action rank.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {cards.map((k, i) => (
          <div key={i} style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12, background: '#fff' }}>
            <div style={{ fontSize: 11, color: '#777', textTransform: 'uppercase', letterSpacing: 0.4 }}>{k.label}</div>
            <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Per-action ROI rank</h2>
        <DataTable columns={rankCols} rows={perAction} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Top ROI saves</h2>
        <DataTable columns={topCols} rows={topSaves} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Worst ROI / churned</h2>
        <DataTable columns={worstCols} rows={worstSaves} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent save actions</h2>
        <DataTable columns={recentCols} rows={recent} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
