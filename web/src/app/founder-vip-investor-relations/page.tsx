import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function rupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  const v = Number(n);
  if (!Number.isFinite(v)) return '-';
  if (Math.abs(v) >= 10000000) return `Rs ${(v / 10000000).toFixed(2)} Cr`;
  if (Math.abs(v) >= 100000) return `Rs ${(v / 100000).toFixed(2)} L`;
  return `Rs ${v.toLocaleString('en-IN')}`;
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '-';
  try { return new Date(s).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }); } catch { return '-'; }
}

function fmtDateTime(s: string | null | undefined): string {
  if (!s) return '-';
  try { return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }); } catch { return '-'; }
}

export default async function FounderVipInvestorRelationsPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = null;
  let roster: any[] = [];
  let recent: any[] = [];
  let calls: any[] = [];
  let tranches: any[] = [];
  let sentiment: any[] = [];

  try {
    const r = await sb.rpc('founder_vip_kpis');
    kpis = Array.isArray(r.data) ? r.data[0] : r.data;
  } catch { kpis = null; }

  try {
    const r = await sb.rpc('founder_vip_roster');
    roster = Array.isArray(r.data) ? r.data : [];
  } catch { roster = []; }

  try {
    const r = await sb.rpc('founder_vip_recent_touchpoints', { p_limit: 30 });
    recent = Array.isArray(r.data) ? r.data : [];
  } catch { recent = []; }

  try {
    const r = await sb.rpc('founder_vip_calls_due');
    calls = Array.isArray(r.data) ? r.data : [];
  } catch { calls = []; }

  try {
    const r = await sb.rpc('founder_vip_tranches_due');
    tranches = Array.isArray(r.data) ? r.data : [];
  } catch { tranches = []; }

  try {
    const r = await sb.rpc('founder_vip_sentiment_trend');
    sentiment = Array.isArray(r.data) ? r.data : [];
  } catch { sentiment = []; }

  const k: Kpi[] = [
    { label: 'Total VIPs', value: String(kpis?.total_vips ?? 0) },
    { label: 'Active VIPs', value: String(kpis?.active_vips ?? 0) },
    { label: 'Platinum tier', value: String(kpis?.platinum_vips ?? 0) },
    { label: 'Total commitment', value: rupees(kpis?.total_commitment_rupees ?? 0) },
    { label: 'Total drawn', value: rupees(kpis?.total_drawn_rupees ?? 0) },
    { label: 'Remaining capital', value: rupees(kpis?.total_remaining_rupees ?? 0) },
    { label: 'Overall draw %', value: `${kpis?.overall_draw_pct ?? 0}%` },
    { label: 'Next tranche pool', value: rupees(kpis?.next_tranche_total_rupees ?? 0) },
    { label: 'Tranches due 30d', value: String(kpis?.tranches_due_30d ?? 0) },
    { label: 'Calls overdue', value: String(kpis?.calls_overdue ?? 0) },
    { label: 'Calls due 7d', value: String(kpis?.calls_due_7d ?? 0) },
    { label: 'Calls logged 30d', value: String(kpis?.calls_logged_30d ?? 0) },
    { label: 'Advance news 30d', value: String(kpis?.advance_news_sent_30d ?? 0) },
    { label: 'Open blockers', value: String(kpis?.blockers_open ?? 0) },
    { label: 'Positive 30d', value: String(kpis?.positive_sentiment_30d ?? 0) },
    { label: 'Avg cadence days', value: String(kpis?.avg_cadence_days ?? 0) },
  ];

  const rosterCols: Column<any>[] = [
    { key: 'full_name', header: 'VIP', render: (r: any) => `${r.full_name ?? '-'}${r.firm_name ? ' (' + r.firm_name + ')' : ''}` },
    { key: 'tier', header: 'Tier', render: (r: any) => (r.tier ?? '-').toUpperCase() },
    { key: 'role_label', header: 'Role', render: (r: any) => (r.role_label ?? '-').replace(/_/g, ' ') },
    { key: 'commitment_rupees', header: 'Committed', render: (r: any) => rupees(r.commitment_rupees) },
    { key: 'drawn_rupees', header: 'Drawn', render: (r: any) => rupees(r.drawn_rupees) },
    { key: 'draw_pct', header: 'Draw %', render: (r: any) => `${r.draw_pct ?? 0}%` },
    { key: 'next_tranche_rupees', header: 'Next tranche', render: (r: any) => rupees(r.next_tranche_rupees) },
    { key: 'next_tranche_due_on', header: 'Due', render: (r: any) => fmtDate(r.next_tranche_due_on) },
    { key: 'next_one_to_one_at', header: 'Next 1:1', render: (r: any) => fmtDateTime(r.next_one_to_one_at) },
    { key: 'active', header: 'Active', render: (r: any) => (r.active ? 'yes' : 'no') },
  ];

  const callsCols: Column<any>[] = [
    { key: 'full_name', header: 'VIP', render: (r: any) => r.full_name ?? '-' },
    { key: 'tier', header: 'Tier', render: (r: any) => (r.tier ?? '-').toUpperCase() },
    { key: 'role_label', header: 'Role', render: (r: any) => (r.role_label ?? '-').replace(/_/g, ' ') },
    { key: 'next_one_to_one_at', header: 'Scheduled', render: (r: any) => fmtDateTime(r.next_one_to_one_at) },
    { key: 'days_to_call', header: 'Days', render: (r: any) => String(r.days_to_call ?? '-') },
    { key: 'is_overdue', header: 'Status', render: (r: any) => (r.is_overdue ? 'OVERDUE' : 'upcoming') },
    { key: 'last_one_to_one_at', header: 'Last 1:1', render: (r: any) => fmtDateTime(r.last_one_to_one_at) },
    { key: 'cadence_days', header: 'Cadence', render: (r: any) => `${r.cadence_days ?? '-'}d` },
  ];

  const tranchesCols: Column<any>[] = [
    { key: 'full_name', header: 'VIP', render: (r: any) => r.full_name ?? '-' },
    { key: 'tier', header: 'Tier', render: (r: any) => (r.tier ?? '-').toUpperCase() },
    { key: 'next_tranche_rupees', header: 'Tranche', render: (r: any) => rupees(r.next_tranche_rupees) },
    { key: 'next_tranche_due_on', header: 'Due', render: (r: any) => fmtDate(r.next_tranche_due_on) },
    { key: 'days_to_due', header: 'Days', render: (r: any) => String(r.days_to_due ?? '-') },
    { key: 'commitment_rupees', header: 'Committed', render: (r: any) => rupees(r.commitment_rupees) },
    { key: 'drawn_rupees', header: 'Drawn', render: (r: any) => rupees(r.drawn_rupees) },
    { key: 'remaining_rupees', header: 'Remaining', render: (r: any) => rupees(r.remaining_rupees) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'occurred_at', header: 'When', render: (r: any) => fmtDateTime(r.occurred_at) },
    { key: 'vip_name', header: 'VIP', render: (r: any) => r.vip_name ?? '-' },
    { key: 'tier', header: 'Tier', render: (r: any) => (r.tier ?? '-').toUpperCase() },
    { key: 'touchpoint_kind', header: 'Kind', render: (r: any) => (r.touchpoint_kind ?? '-').replace(/_/g, ' ') },
    { key: 'subject', header: 'Subject', render: (r: any) => r.subject ?? '-' },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => r.sentiment ?? '-' },
    { key: 'next_action', header: 'Next action', render: (r: any) => r.next_action ?? '-' },
  ];

  const sentimentCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => fmtDate(r.week_start) },
    { key: 'positive_count', header: 'Positive', render: (r: any) => String(r.positive_count ?? 0) },
    { key: 'neutral_count', header: 'Neutral', render: (r: any) => String(r.neutral_count ?? 0) },
    { key: 'concerned_count', header: 'Concerned', render: (r: any) => String(r.concerned_count ?? 0) },
    { key: 'blocker_count', header: 'Blocker', render: (r: any) => String(r.blocker_count ?? 0) },
    { key: 'total_touchpoints', header: 'Total', render: (r: any) => String(r.total_touchpoints ?? 0) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>Founder VIP Investor Relations</h1>
        <p style={{ color: '#64748b', fontSize: 14 }}>
          White-glove tier: lead investor + board chair. 1:1 monthly calls, custom KPI dashboards, advance access to news, per-VIP commitment tracker.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 28 }}>
        {k.map((kpi) => (
          <div key={kpi.label} style={{ background: '#fff', border: '1px solid #e2e8f0', borderRadius: 8, padding: 14 }}>
            <div style={{ fontSize: 11, color: '#64748b', textTransform: 'uppercase', letterSpacing: 0.5 }}>{kpi.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{kpi.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>VIP roster</h2>
        <DataTable columns={rosterCols} rows={roster} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Calls due (next 14 days)</h2>
        <DataTable columns={callsCols} rows={calls} rowKey={(r: any) => r.vip_id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Tranches due</h2>
        <DataTable columns={tranchesCols} rows={tranches} rowKey={(r: any) => r.vip_id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent touchpoints</h2>
        <DataTable columns={recentCols} rows={recent} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Sentiment trend (12 weeks)</h2>
        <DataTable columns={sentimentCols} rows={sentiment} rowKey={(r: any) => String(r.week_start)} />
      </section>
    </main>
  );
}
