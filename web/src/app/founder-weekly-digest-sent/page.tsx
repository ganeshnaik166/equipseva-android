import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtInt(n: any): string {
  const v = Number(n ?? 0);
  if (!isFinite(v)) return "0";
  return v.toLocaleString('en-IN');
}

function fmtPct(n: any): string {
  const v = Number(n ?? 0);
  if (!isFinite(v)) return "0%";
  return `${v.toFixed(2)}%`;
}

function fmtDate(s: any): string {
  if (!s) return "—";
  try { return new Date(s).toLocaleString('en-IN'); } catch { return String(s); }
}

export default async function FounderWeeklyDigestSentPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let recentSends: any[] = [];
  let abTest: any[] = [];
  let topRecipients: any[] = [];
  let byAudience: any[] = [];

  try {
    const r = await sb.rpc('founder_weekly_digest_kpis_v2');
    kpis = r.data ?? {};
  } catch { kpis = {}; }

  try {
    const r = await sb.rpc('founder_weekly_digest_recent_sends_v2', { p_limit: 50 });
    recentSends = (r.data as any[]) ?? [];
  } catch { recentSends = []; }

  try {
    const r = await sb.rpc('founder_weekly_digest_ab_test_v2');
    abTest = (r.data as any[]) ?? [];
  } catch { abTest = []; }

  try {
    const r = await sb.rpc('founder_weekly_digest_top_recipients_v2', { p_limit: 25 });
    topRecipients = (r.data as any[]) ?? [];
  } catch { topRecipients = []; }

  try {
    const r = await sb.rpc('founder_weekly_digest_by_audience_v2');
    byAudience = (r.data as any[]) ?? [];
  } catch { byAudience = []; }

  const cards: Kpi[] = [
    { label: "Total Sends", value: fmtInt(kpis.total_sends) },
    { label: "Sends 30d", value: fmtInt(kpis.sends_last_30d) },
    { label: "Sends 90d", value: fmtInt(kpis.sends_last_90d) },
    { label: "Investor Sends", value: fmtInt(kpis.investor_sends) },
    { label: "Team Sends", value: fmtInt(kpis.team_sends) },
    { label: "Board Sends", value: fmtInt(kpis.board_sends) },
    { label: "Total Recipients", value: fmtInt(kpis.total_recipients) },
    { label: "Total Opens", value: fmtInt(kpis.total_opens) },
    { label: "Total Clicks", value: fmtInt(kpis.total_clicks) },
    { label: "Avg Open Rate", value: fmtPct(kpis.avg_open_rate_pct) },
    { label: "Avg Click Rate", value: fmtPct(kpis.avg_click_rate_pct) },
    { label: "Total Bounces", value: fmtInt(kpis.total_bounces) },
    { label: "Total Unsubs", value: fmtInt(kpis.total_unsubscribes) },
    { label: "Variant A", value: fmtInt(kpis.variant_a_sends) },
    { label: "Variant B", value: fmtInt(kpis.variant_b_sends) },
    { label: "Last Send", value: fmtDate(kpis.last_send_at) },
  ];

  const sendsCols: Column<any>[] = [
    { key: 'sent_at', header: 'Sent At', render: (r: any) => fmtDate(r.sent_at) },
    { key: 'digest_week_start', header: 'Week', render: (r: any) => r.digest_week_start ?? "—" },
    { key: 'audience', header: 'Audience', render: (r: any) => r.audience ?? "—" },
    { key: 'subject_variant', header: 'Variant', render: (r: any) => r.subject_variant ?? "—" },
    { key: 'subject_line', header: 'Subject', render: (r: any) => r.subject_line ?? "—" },
    { key: 'recipient_count', header: 'Recipients', render: (r: any) => fmtInt(r.recipient_count) },
    { key: 'opens_count', header: 'Opens', render: (r: any) => fmtInt(r.opens_count) },
    { key: 'clicks_count', header: 'Clicks', render: (r: any) => fmtInt(r.clicks_count) },
    { key: 'open_rate_pct', header: 'Open %', render: (r: any) => fmtPct(r.open_rate_pct) },
    { key: 'click_rate_pct', header: 'Click %', render: (r: any) => fmtPct(r.click_rate_pct) },
  ];

  const abCols: Column<any>[] = [
    { key: 'subject_variant', header: 'Variant', render: (r: any) => r.subject_variant ?? "—" },
    { key: 'sends', header: 'Sends', render: (r: any) => fmtInt(r.sends) },
    { key: 'total_recipients', header: 'Recipients', render: (r: any) => fmtInt(r.total_recipients) },
    { key: 'total_opens', header: 'Opens', render: (r: any) => fmtInt(r.total_opens) },
    { key: 'total_clicks', header: 'Clicks', render: (r: any) => fmtInt(r.total_clicks) },
    { key: 'open_rate_pct', header: 'Open %', render: (r: any) => fmtPct(r.open_rate_pct) },
    { key: 'click_rate_pct', header: 'Click %', render: (r: any) => fmtPct(r.click_rate_pct) },
  ];

  const topCols: Column<any>[] = [
    { key: 'recipient_email', header: 'Email', render: (r: any) => r.recipient_email ?? "—" },
    { key: 'recipient_name', header: 'Name', render: (r: any) => r.recipient_name ?? "—" },
    { key: 'recipient_role', header: 'Role', render: (r: any) => r.recipient_role ?? "—" },
    { key: 'sends_received', header: 'Sends', render: (r: any) => fmtInt(r.sends_received) },
    { key: 'opens', header: 'Opens', render: (r: any) => fmtInt(r.opens) },
    { key: 'clicks', header: 'Clicks', render: (r: any) => fmtInt(r.clicks) },
    { key: 'last_open_at', header: 'Last Open', render: (r: any) => fmtDate(r.last_open_at) },
  ];

  const audCols: Column<any>[] = [
    { key: 'audience', header: 'Audience', render: (r: any) => r.audience ?? "—" },
    { key: 'sends', header: 'Sends', render: (r: any) => fmtInt(r.sends) },
    { key: 'total_recipients', header: 'Recipients', render: (r: any) => fmtInt(r.total_recipients) },
    { key: 'open_rate_pct', header: 'Open %', render: (r: any) => fmtPct(r.open_rate_pct) },
    { key: 'click_rate_pct', header: 'Click %', render: (r: any) => fmtPct(r.click_rate_pct) },
  ];

  const sendsWithId = recentSends.map((s: any) => ({ ...s, id: s.id ?? `${s.sent_at}-${s.subject_line}` }));
  const abWithId = abTest.map((s: any) => ({ ...s, id: s.subject_variant }));
  const topWithId = topRecipients.map((s: any) => ({ ...s, id: s.recipient_email }));
  const audWithId = byAudience.map((s: any) => ({ ...s, id: s.audience }));

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Founder Weekly Digest Sent Log</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Every weekly digest sent to investors, team, board. Recipient lists, open/click rates, A/B subject-line tests, per-recipient engagement.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 32 }}>
        {cards.map((k) => (
          <div key={k.label} style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8, background: '#fff' }}>
            <div style={{ fontSize: 12, color: '#666', textTransform: 'uppercase', letterSpacing: 0.5 }}>{k.label}</div>
            <div style={{ fontSize: 22, fontWeight: 600, marginTop: 6 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Sends</h2>
        <DataTable<any> rows={sendsWithId} columns={sendsCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>A/B Subject-Line Test</h2>
        <DataTable<any> rows={abWithId} columns={abCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Engaged Recipients</h2>
        <DataTable<any> rows={topWithId} columns={topCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>By Audience</h2>
        <DataTable<any> rows={audWithId} columns={audCols} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
