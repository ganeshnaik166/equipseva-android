import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return "₹0";
  return "₹" + Number(n).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return "—";
  try { return new Date(s).toLocaleDateString('en-IN', { year: 'numeric', month: 'short', day: '2-digit' }); }
  catch { return s; }
}

async function loadAll() {
  const sb = await getSupabaseServerClient();
  let kpis: any = {};
  let list: any[] = [];
  let pending: any[] = [];
  let byRisk: any[] = [];
  let topRec: any[] = [];
  let events: any[] = [];
  try {
    const r = await sb.rpc('founder_retention_bonus_kpis');
    if (!r.error) kpis = r.data ?? {};
  } catch { kpis = {}; }
  try {
    const r = await sb.rpc('founder_retention_bonus_list', { p_limit: 100 });
    if (!r.error) list = r.data ?? [];
  } catch { list = []; }
  try {
    const r = await sb.rpc('founder_retention_bonus_pending');
    if (!r.error) pending = r.data ?? [];
  } catch { pending = []; }
  try {
    const r = await sb.rpc('founder_retention_bonus_by_risk');
    if (!r.error) byRisk = r.data ?? [];
  } catch { byRisk = []; }
  try {
    const r = await sb.rpc('founder_retention_bonus_top_recipients', { p_limit: 20 });
    if (!r.error) topRec = r.data ?? [];
  } catch { topRec = []; }
  try {
    const r = await sb.rpc('founder_retention_bonus_event_log', { p_limit: 100 });
    if (!r.error) events = r.data ?? [];
  } catch { events = []; }
  return { kpis, list, pending, byRisk, topRec, events };
}

export default async function Page() {
  await requireFounder();
  const { kpis, list, pending, byRisk, topRec, events } = await loadAll();

  const cards: Kpi[] = [
    { label: 'Total bonuses', value: String(kpis?.total ?? 0) },
    { label: 'Proposed', value: String(kpis?.proposed ?? 0) },
    { label: 'L1 approved', value: String(kpis?.l1_approved ?? 0) },
    { label: 'L2 approved', value: String(kpis?.l2_approved ?? 0) },
    { label: 'Paid', value: String(kpis?.paid ?? 0) },
    { label: 'Rejected', value: String(kpis?.rejected ?? 0) },
    { label: 'Cancelled', value: String(kpis?.cancelled ?? 0) },
    { label: 'Paid total', value: fmtRupees(kpis?.paid_total) },
    { label: 'Pipeline total', value: fmtRupees(kpis?.pipeline_total) },
    { label: 'Avg paid', value: fmtRupees(kpis?.avg_paid) },
    { label: 'Max paid', value: fmtRupees(kpis?.max_paid) },
    { label: 'Last 30d', value: String(kpis?.last_30d ?? 0) },
    { label: 'Last 7d', value: String(kpis?.last_7d ?? 0) },
    { label: 'Unique engineers', value: String(kpis?.unique_engineers ?? 0) },
    { label: 'Active retention', value: String(kpis?.active_now ?? 0) },
    { label: 'Avg duration (mo)', value: String(kpis?.avg_duration_months ?? 0) },
  ];

  const listCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? "—" },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.amount_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? "—" },
    { key: 'risk_signal', header: 'Risk', render: (r: any) => r.risk_signal ?? "—" },
    { key: 'duration_months', header: 'Months', render: (r: any) => String(r.duration_months ?? "—") },
    { key: 'created_at', header: 'Proposed', render: (r: any) => fmtDate(r.created_at) },
    { key: 'effective_until', header: 'Effective until', render: (r: any) => fmtDate(r.effective_until) },
  ];

  const pendingCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? "—" },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.amount_rupees) },
    { key: 'risk_signal', header: 'Risk', render: (r: any) => r.risk_signal ?? "—" },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? "—" },
    { key: 'awaiting', header: 'Awaiting', render: (r: any) => r.awaiting ?? "—" },
    { key: 'created_at', header: 'Proposed', render: (r: any) => fmtDate(r.created_at) },
  ];

  const riskCols: Column<any>[] = [
    { key: 'risk_signal', header: 'Risk signal', render: (r: any) => r.risk_signal ?? "—" },
    { key: 'bonus_count', header: 'Bonuses', render: (r: any) => String(r.bonus_count ?? 0) },
    { key: 'paid_count', header: 'Paid', render: (r: any) => String(r.paid_count ?? 0) },
    { key: 'total_rupees', header: 'Total paid', render: (r: any) => fmtRupees(r.total_rupees) },
    { key: 'avg_amount', header: 'Avg amount', render: (r: any) => fmtRupees(r.avg_amount) },
  ];

  const topCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? "—" },
    { key: 'tier', header: 'Tier', render: (r: any) => r.tier ?? "—" },
    { key: 'bonus_count', header: 'Bonuses', render: (r: any) => String(r.bonus_count ?? 0) },
    { key: 'paid_total', header: 'Paid total', render: (r: any) => fmtRupees(r.paid_total) },
    { key: 'last_paid_at', header: 'Last paid', render: (r: any) => fmtDate(r.last_paid_at) },
  ];

  const eventCols: Column<any>[] = [
    { key: 'event_type', header: 'Event', render: (r: any) => r.event_type ?? "—" },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? "—" },
    { key: 'created_at', header: 'When', render: (r: any) => fmtDate(r.created_at) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif', maxWidth: 1400, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, margin: 0 }}>Engineer Retention Bonus Log</h1>
        <p style={{ color: '#555', marginTop: 6 }}>
          Pay retention bonuses to high-performers at risk of leaving. Per-engineer amount, reason, duration with founder approval ladder (L1 then L2).
        </p>
      </header>

      <section aria-label="KPIs" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 32 }}>
        {cards.map((k, i) => (
          <div key={i} style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12, background: '#fafafa' }}>
            <div style={{ fontSize: 12, color: '#666', textTransform: 'uppercase' }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Pending approval ladder</h2>
        <DataTable rows={pending} columns={pendingCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All retention bonuses</h2>
        <DataTable rows={list} columns={listCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>By risk signal</h2>
        <DataTable rows={byRisk} columns={riskCols} rowKey={(r: any) => r.risk_signal} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top recipients</h2>
        <DataTable rows={topRec} columns={topCols} rowKey={(r: any) => r.engineer_id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent events</h2>
        <DataTable rows={events} columns={eventCols} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
