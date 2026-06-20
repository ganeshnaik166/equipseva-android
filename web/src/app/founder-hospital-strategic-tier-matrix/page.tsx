import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return '₹0';
  return '₹' + Math.round(n).toLocaleString('en-IN');
}

function fmtNum(n: number | null | undefined, digits = 0): string {
  if (n == null) return '0';
  return Number(n).toFixed(digits);
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '—';
  try { return new Date(s).toLocaleString('en-IN'); } catch { return '—'; }
}

function quadrantLabel(q: string | null | undefined): string {
  switch (q) {
    case 'star': return 'Star';
    case 'cash_cow': return 'Cash Cow';
    case 'question_mark': return 'Question Mark';
    case 'dog': return 'Dog';
    default: return '—';
  }
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let overview: any = null;
  let listRows: any[] = [];
  let quadRows: any[] = [];
  let playbookRows: any[] = [];
  let reviewRows: any[] = [];
  let moverRows: any[] = [];

  try {
    const r = await sb.rpc('founder_hospital_matrix_overview');
    overview = Array.isArray(r.data) ? r.data[0] : r.data;
  } catch { overview = null; }

  try {
    const r = await sb.rpc('founder_hospital_matrix_list');
    listRows = Array.isArray(r.data) ? r.data : [];
  } catch { listRows = []; }

  try {
    const r = await sb.rpc('founder_hospital_matrix_quadrants');
    quadRows = Array.isArray(r.data) ? r.data : [];
  } catch { quadRows = []; }

  try {
    const r = await sb.rpc('founder_hospital_matrix_playbook');
    playbookRows = Array.isArray(r.data) ? r.data : [];
  } catch { playbookRows = []; }

  try {
    const r = await sb.rpc('founder_hospital_matrix_reviews_due');
    reviewRows = Array.isArray(r.data) ? r.data : [];
  } catch { reviewRows = []; }

  try {
    const r = await sb.rpc('founder_hospital_matrix_top_movers');
    moverRows = Array.isArray(r.data) ? r.data : [];
  } catch { moverRows = []; }

  try { await sb.rpc('log_founder_matrix_view'); } catch {}

  const o = overview ?? {};

  const kpis: Kpi[] = [
    { label: 'Total Hospitals', value: fmtNum(o.total_hospitals) },
    { label: 'Unscored', value: fmtNum(o.unscored_hospitals) },
    { label: 'Stars', value: fmtNum(o.stars) },
    { label: 'Cash Cows', value: fmtNum(o.cash_cows) },
    { label: 'Question Marks', value: fmtNum(o.question_marks) },
    { label: 'Dogs', value: fmtNum(o.dogs) },
    { label: 'Total 90d Revenue', value: fmtRupees(o.total_trailing_revenue) },
    { label: 'Star Revenue', value: fmtRupees(o.stars_revenue) },
    { label: 'Cash Cow Revenue', value: fmtRupees(o.cash_cows_revenue) },
    { label: 'Question Mark Rev', value: fmtRupees(o.question_marks_revenue) },
    { label: 'Dog Revenue', value: fmtRupees(o.dogs_revenue) },
    { label: 'Avg Revenue Score', value: fmtNum(o.avg_revenue_score, 1) },
    { label: 'Avg Fit Score', value: fmtNum(o.avg_fit_score, 1) },
    { label: 'Reviews Overdue', value: fmtNum(o.overdue_reviews) },
    { label: 'Reviews Due 7d', value: fmtNum(o.reviews_due_7d) },
    { label: 'Last Recompute', value: fmtDate(o.last_recompute_at) },
  ];

  const hospitalCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'quadrant', header: 'Quadrant', render: (r: any) => quadrantLabel(r.quadrant) },
    { key: 'revenue_score', header: 'Rev Score', render: (r: any) => fmtNum(r.revenue_score, 1) },
    { key: 'strategic_fit_score', header: 'Fit Score', render: (r: any) => fmtNum(r.strategic_fit_score, 1) },
    { key: 'trailing_90d_revenue_rupees', header: '90d Revenue', render: (r: any) => fmtRupees(r.trailing_90d_revenue_rupees) },
    { key: 'active_contracts', header: 'Active AMC', render: (r: any) => fmtNum(r.active_contracts) },
    { key: 'next_review_at', header: 'Next Review', render: (r: any) => fmtDate(r.next_review_at) },
  ];

  const quadCols: Column<any>[] = [
    { key: 'quadrant', header: 'Quadrant', render: (r: any) => quadrantLabel(r.quadrant) },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => fmtNum(r.hospital_count) },
    { key: 'total_revenue', header: 'Total Revenue', render: (r: any) => fmtRupees(r.total_revenue) },
    { key: 'avg_revenue_score', header: 'Avg Rev', render: (r: any) => fmtNum(r.avg_revenue_score, 1) },
    { key: 'avg_fit_score', header: 'Avg Fit', render: (r: any) => fmtNum(r.avg_fit_score, 1) },
    { key: 'avg_review_cadence_days', header: 'Cadence (d)', render: (r: any) => fmtNum(r.avg_review_cadence_days, 0) },
    { key: 'overdue_count', header: 'Overdue', render: (r: any) => fmtNum(r.overdue_count) },
  ];

  const playbookCols: Column<any>[] = [
    { key: 'quadrant', header: 'Quadrant', render: (r: any) => quadrantLabel(r.quadrant) },
    { key: 'step_order', header: 'Step', render: (r: any) => fmtNum(r.step_order) },
    { key: 'action_label', header: 'Action', render: (r: any) => r.action_label ?? '—' },
    { key: 'owner_role', header: 'Owner', render: (r: any) => r.owner_role ?? '—' },
    { key: 'cadence_days', header: 'Cadence (d)', render: (r: any) => fmtNum(r.cadence_days) },
  ];

  const reviewCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'quadrant', header: 'Quadrant', render: (r: any) => quadrantLabel(r.quadrant) },
    { key: 'next_review_at', header: 'Due', render: (r: any) => fmtDate(r.next_review_at) },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => fmtNum(r.days_overdue, 1) },
    { key: 'trailing_90d_revenue_rupees', header: '90d Revenue', render: (r: any) => fmtRupees(r.trailing_90d_revenue_rupees) },
  ];

  const moverCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'quadrant', header: 'Quadrant', render: (r: any) => quadrantLabel(r.quadrant) },
    { key: 'revenue_score', header: 'Rev Score', render: (r: any) => fmtNum(r.revenue_score, 1) },
    { key: 'strategic_fit_score', header: 'Fit Score', render: (r: any) => fmtNum(r.strategic_fit_score, 1) },
    { key: 'trailing_90d_revenue_rupees', header: '90d Revenue', render: (r: any) => fmtRupees(r.trailing_90d_revenue_rupees) },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>Hospital Strategic-Tier Matrix</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        2x2 matrix plotting every hospital on revenue vs strategic fit, with per-quadrant playbooks and founder review cadence.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: 12, marginBottom: 28 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fafafa' }}>
            <div style={{ fontSize: 12, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.4 }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Quadrant Breakdown</h2>
        <DataTable columns={quadCols} rows={quadRows} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Hospitals on the Matrix</h2>
        <DataTable columns={hospitalCols} rows={listRows} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Per-Quadrant Action Playbook</h2>
        <DataTable columns={playbookCols} rows={playbookRows} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Reviews Due (next 7 days + overdue)</h2>
        <DataTable columns={reviewCols} rows={reviewRows} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Top Revenue Hospitals</h2>
        <DataTable columns={moverCols} rows={moverRows} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
