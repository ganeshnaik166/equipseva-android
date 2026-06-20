import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtInr(rupees: number | null | undefined): string {
  const n = Number(rupees ?? 0);
  if (!isFinite(n) || n === 0) return '₹0';
  if (n >= 1e7) return '₹' + (n / 1e7).toFixed(2) + ' Cr';
  if (n >= 1e5) return '₹' + (n / 1e5).toFixed(2) + ' L';
  return '₹' + n.toLocaleString('en-IN');
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let recent: any[] = [];
  let stale: any[] = [];
  let overdue: any[] = [];
  let closingWeek: any[] = [];
  let byStatus: any[] = [];
  let events: any[] = [];

  try {
    const r = await sb.rpc('founder_loi_kpis');
    kpis = r.data ?? {};
  } catch { kpis = {}; }
  try {
    const r = await sb.rpc('founder_loi_list_recent');
    recent = (r.data as any[]) ?? [];
  } catch { recent = []; }
  try {
    const r = await sb.rpc('founder_loi_stale_signed');
    stale = (r.data as any[]) ?? [];
  } catch { stale = []; }
  try {
    const r = await sb.rpc('founder_loi_overdue_close_by');
    overdue = (r.data as any[]) ?? [];
  } catch { overdue = []; }
  try {
    const r = await sb.rpc('founder_loi_closing_this_week');
    closingWeek = (r.data as any[]) ?? [];
  } catch { closingWeek = []; }
  try {
    const r = await sb.rpc('founder_loi_by_status');
    byStatus = (r.data as any[]) ?? [];
  } catch { byStatus = []; }
  try {
    const r = await sb.rpc('founder_loi_recent_events');
    events = (r.data as any[]) ?? [];
  } catch { events = []; }

  const cards: Kpi[] = [
    { label: 'Total LOIs / term-sheets', value: String(kpis.total_count ?? 0) },
    { label: 'Signed (open)', value: String(kpis.signed_count ?? 0) },
    { label: 'In diligence', value: String(kpis.in_diligence_count ?? 0) },
    { label: 'Funds wired', value: String(kpis.funds_wired_count ?? 0) },
    { label: 'Closed', value: String(kpis.closed_count ?? 0) },
    { label: 'Withdrawn', value: String(kpis.withdrawn_count ?? 0) },
    { label: 'Expired', value: String(kpis.expired_count ?? 0) },
    { label: 'Binding docs', value: String(kpis.binding_count ?? 0) },
    { label: 'Non-binding docs', value: String(kpis.non_binding_count ?? 0) },
    { label: 'Total commit (all)', value: fmtInr(kpis.total_commit_rupees) },
    { label: 'Open commit (signed + DD)', value: fmtInr(kpis.open_commit_rupees) },
    { label: 'Wired so far', value: fmtInr(kpis.wired_rupees) },
    { label: 'Closed ₹', value: fmtInr(kpis.closed_rupees) },
    { label: 'Stale open (>30d)', value: String(kpis.stale_open_count ?? 0) },
    { label: 'Overdue close-by', value: String(kpis.overdue_close_by_count ?? 0) },
    { label: 'Closing in 7 days', value: String(kpis.closing_this_week_count ?? 0) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => String(r.investor_name ?? '—') },
    { key: 'investor_firm', header: 'Firm', render: (r: any) => String(r.investor_firm ?? '—') },
    { key: 'doc_kind', header: 'Kind', render: (r: any) => String(r.doc_kind ?? '—') },
    { key: 'is_binding', header: 'Binding', render: (r: any) => (r.is_binding ? 'Yes' : 'No') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '—') },
    { key: 'commit_amount_rupees', header: 'Commit', render: (r: any) => fmtInr(r.commit_amount_rupees) },
    { key: 'close_by_date', header: 'Close by', render: (r: any) => String(r.close_by_date ?? '—') },
    { key: 'age_days', header: 'Age (d)', render: (r: any) => String(r.age_days ?? '—') },
  ];

  const staleCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => String(r.investor_name ?? '—') },
    { key: 'investor_firm', header: 'Firm', render: (r: any) => String(r.investor_firm ?? '—') },
    { key: 'doc_kind', header: 'Kind', render: (r: any) => String(r.doc_kind ?? '—') },
    { key: 'is_binding', header: 'Binding', render: (r: any) => (r.is_binding ? 'Yes' : 'No') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '—') },
    { key: 'commit_amount_rupees', header: 'Commit', render: (r: any) => fmtInr(r.commit_amount_rupees) },
    { key: 'days_stale', header: 'Days stale', render: (r: any) => String(r.days_stale ?? '—') },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => String(r.investor_name ?? '—') },
    { key: 'investor_firm', header: 'Firm', render: (r: any) => String(r.investor_firm ?? '—') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '—') },
    { key: 'is_binding', header: 'Binding', render: (r: any) => (r.is_binding ? 'Yes' : 'No') },
    { key: 'commit_amount_rupees', header: 'Commit', render: (r: any) => fmtInr(r.commit_amount_rupees) },
    { key: 'close_by_date', header: 'Close by', render: (r: any) => String(r.close_by_date ?? '—') },
    { key: 'days_overdue', header: 'Days overdue', render: (r: any) => String(r.days_overdue ?? '—') },
  ];

  const closingCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => String(r.investor_name ?? '—') },
    { key: 'investor_firm', header: 'Firm', render: (r: any) => String(r.investor_firm ?? '—') },
    { key: 'is_binding', header: 'Binding', render: (r: any) => (r.is_binding ? 'Yes' : 'No') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '—') },
    { key: 'commit_amount_rupees', header: 'Commit', render: (r: any) => fmtInr(r.commit_amount_rupees) },
    { key: 'close_by_date', header: 'Close by', render: (r: any) => String(r.close_by_date ?? '—') },
    { key: 'days_until', header: 'Days until', render: (r: any) => String(r.days_until ?? '—') },
  ];

  const byStatusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '—') },
    { key: 'cnt', header: 'Count', render: (r: any) => String(r.cnt ?? 0) },
    { key: 'binding_cnt', header: 'Of which binding', render: (r: any) => String(r.binding_cnt ?? 0) },
    { key: 'total_rupees', header: 'Total commit', render: (r: any) => fmtInr(r.total_rupees) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Investor signed-LOI tracker
      </h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Round r1539 · separate from cap table · every signed LOI / term-sheet, with stale + overdue surfacing.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 12, marginBottom: 24 }}>
        {cards.map((k, i) => (
          <div key={i} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
            <div style={{ fontSize: 12, color: '#6b7280' }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '16px 0 8px' }}>Recent LOIs (latest 100)</h2>
      <DataTable columns={recentCols} rows={recent} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Stale signed (open {">"} 30 days)</h2>
      <DataTable columns={staleCols} rows={stale} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Overdue close-by</h2>
      <DataTable columns={overdueCols} rows={overdue} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Closing in next 7 days</h2>
      <DataTable columns={closingCols} rows={closingWeek} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Breakdown by status</h2>
      <DataTable columns={byStatusCols} rows={byStatus} rowKey={(r: any) => String(r.status)} />

      <p style={{ marginTop: 24, color: '#6b7280', fontSize: 12 }}>
        Recent events logged: {events.length}
      </p>
    </main>
  );
}
