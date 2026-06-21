import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '₹0';
  return '₹' + Math.round(Number(n)).toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '0%';
  return Number(n).toFixed(1) + '%';
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpiRow: any = {};
  let actions: any[] = [];
  let monthly: any[] = [];
  let top: any[] = [];
  let bottom: any[] = [];

  try {
    const r = await sb.rpc('founder_save_rate_kpis');
    kpiRow = (r.data && r.data[0]) || {};
  } catch {}
  try {
    const r = await sb.rpc('founder_save_action_effectiveness_list');
    actions = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_save_rate_monthly_list');
    monthly = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_save_action_top_performers');
    top = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_save_action_bottom_performers');
    bottom = r.data || [];
  } catch {}

  const kpis: Kpi[] = [
    { label: 'Total Attempts', value: String(kpiRow.total_attempts ?? 0) },
    { label: 'Total Saves', value: String(kpiRow.total_saves ?? 0) },
    { label: 'Total Losses', value: String(kpiRow.total_losses ?? 0) },
    { label: 'Overall Save Rate', value: fmtPct(kpiRow.overall_save_rate_pct) },
    { label: 'Total Cost', value: fmtRupees(kpiRow.total_cost_rupees) },
    { label: 'Revenue Saved', value: fmtRupees(kpiRow.total_revenue_saved_rupees) },
    { label: 'Net Value', value: fmtRupees(kpiRow.net_value_rupees) },
    { label: 'Overall ROI', value: String(kpiRow.overall_roi ?? 0) + 'x' },
    { label: 'Action Types', value: String(actions.length) },
    { label: 'Months Tracked', value: String(monthly.length) },
    { label: 'Top Performers', value: String(top.length) },
    { label: 'Bottom Performers', value: String(bottom.length) },
    { label: 'Best Action', value: top[0]?.action_label ?? '—' },
    { label: 'Worst Action', value: bottom[0]?.action_label ?? '—' },
    { label: 'Latest Month Save Rate', value: fmtPct(monthly[0]?.save_rate_pct) },
    { label: 'Latest Month Net', value: fmtRupees(monthly[0]?.net_value_rupees) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_label', header: 'Action', render: (r: any) => r.action_label ?? '—' },
    { key: 'attempts_count', header: 'Attempts', render: (r: any) => String(r.attempts_count ?? 0) },
    { key: 'saves_count', header: 'Saves', render: (r: any) => String(r.saves_count ?? 0) },
    { key: 'effectiveness_pct', header: 'Effectiveness', render: (r: any) => fmtPct(r.effectiveness_pct) },
    { key: 'avg_cost_rupees', header: 'Avg Cost', render: (r: any) => fmtRupees(r.avg_cost_rupees) },
    { key: 'avg_revenue_saved_rupees', header: 'Avg Revenue Saved', render: (r: any) => fmtRupees(r.avg_revenue_saved_rupees) },
    { key: 'roi_ratio', header: 'ROI', render: (r: any) => String(r.roi_ratio ?? 0) + 'x' },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start ?? '—' },
    { key: 'at_risk_count', header: 'At Risk', render: (r: any) => String(r.at_risk_count ?? 0) },
    { key: 'saved_count', header: 'Saved', render: (r: any) => String(r.saved_count ?? 0) },
    { key: 'lost_count', header: 'Lost', render: (r: any) => String(r.lost_count ?? 0) },
    { key: 'save_rate_pct', header: 'Save Rate', render: (r: any) => fmtPct(r.save_rate_pct) },
    { key: 'total_cost_rupees', header: 'Cost', render: (r: any) => fmtRupees(r.total_cost_rupees) },
    { key: 'total_revenue_saved_rupees', header: 'Revenue Saved', render: (r: any) => fmtRupees(r.total_revenue_saved_rupees) },
    { key: 'net_value_rupees', header: 'Net', render: (r: any) => fmtRupees(r.net_value_rupees) },
  ];

  const topCols: Column<any>[] = [
    { key: 'action_label', header: 'Action', render: (r: any) => r.action_label ?? '—' },
    { key: 'effectiveness_pct', header: 'Effectiveness', render: (r: any) => fmtPct(r.effectiveness_pct) },
    { key: 'saves_count', header: 'Saves', render: (r: any) => String(r.saves_count ?? 0) },
    { key: 'roi_ratio', header: 'ROI', render: (r: any) => String(r.roi_ratio ?? 0) + 'x' },
  ];

  const bottomCols: Column<any>[] = [
    { key: 'action_label', header: 'Action', render: (r: any) => r.action_label ?? '—' },
    { key: 'effectiveness_pct', header: 'Effectiveness', render: (r: any) => fmtPct(r.effectiveness_pct) },
    { key: 'attempts_count', header: 'Attempts', render: (r: any) => String(r.attempts_count ?? 0) },
    { key: 'avg_cost_rupees', header: 'Avg Cost', render: (r: any) => fmtRupees(r.avg_cost_rupees) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>Hospital Churn Save-Rate Analyzer</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>r1563 — aggregates save-plan outcomes from r1559; measures per-action effectiveness, monthly save rate, cost vs revenue saved.</p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 32 }}>
        {kpis.map((k, i) => (
          <div key={i} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 14, background: '#fafafa' }}>
            <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase', letterSpacing: 0.4 }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Per-Action Effectiveness</h2>
        <DataTable rowKey={(r: any) => r.id} columns={actionCols} rows={actions} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Per-Month Save Rate</h2>
        <DataTable rowKey={(r: any) => r.id} columns={monthlyCols} rows={monthly} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Performers</h2>
        <DataTable rowKey={(r: any) => r.action_code} columns={topCols} rows={top} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Bottom Performers</h2>
        <DataTable rowKey={(r: any) => r.action_code} columns={bottomCols} rows={bottom} />
      </section>
    </main>
  );
}
