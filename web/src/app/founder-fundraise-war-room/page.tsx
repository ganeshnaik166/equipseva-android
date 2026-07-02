import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  if (n >= 10000000) return `Rs ${(n / 10000000).toFixed(2)} Cr`;
  if (n >= 100000) return `Rs ${(n / 100000).toFixed(2)} L`;
  return `Rs ${n.toLocaleString('en-IN')}`;
}

export default async function FounderFundraiseWarRoomPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let summary: any = null;
  let meetings: any[] = [];
  let hottest: any[] = [];
  let heatmap: any[] = [];
  let funnel: any[] = [];

  try {
    const r = await sb.rpc('founder_fundraise_active_round_summary');
    summary = (r.data ?? [])[0] ?? null;
  } catch {}
  try {
    const r = await sb.rpc('founder_fundraise_meetings_this_week');
    meetings = (r.data ?? []) as any[];
  } catch {}
  try {
    const r = await sb.rpc('founder_fundraise_hottest_investors', { p_limit: 15 });
    hottest = (r.data ?? []) as any[];
  } catch {}
  try {
    const r = await sb.rpc('founder_fundraise_schedule_heatmap');
    heatmap = (r.data ?? []) as any[];
  } catch {}
  try {
    const r = await sb.rpc('founder_fundraise_funnel_by_status');
    funnel = (r.data ?? []) as any[];
  } catch {}

  const target = Number(summary?.target_rupees ?? 0);
  const softCommit = Number(summary?.soft_commit_total ?? 0);
  const wired = Number(summary?.wired_total ?? 0);
  const pctCommitted = Number(summary?.pct_committed ?? 0);
  const pctWired = Number(summary?.pct_wired ?? 0);
  const daysOpen = Number(summary?.days_open ?? 0);
  const daysToClose = summary?.days_to_close ?? null;
  const investorCount = Number(summary?.investor_count ?? 0);

  const meetingsCount = meetings.length;
  const next48h = meetings.filter((m: any) => Number(m.hours_until ?? 999) <= 48).length;
  const hotCount = hottest.filter((h: any) => Number(h.heat_score ?? 0) >= 80).length;
  const termSheetCount = funnel.find((f: any) => f.status === 'term_sheet')?.investor_count ?? 0;
  const softCommitCount = funnel.find((f: any) => f.status === 'soft_commit')?.investor_count ?? 0;
  const passedCount = funnel.find((f: any) => f.status === 'passed')?.investor_count ?? 0;
  const avgHeat = hottest.length
    ? (hottest.reduce((s: number, h: any) => s + Number(h.heat_score ?? 0), 0) / hottest.length).toFixed(0)
    : '0';
  const remaining = Math.max(target - softCommit, 0);

  const kpis: Kpi[] = [
    { label: 'Round', value: String(summary?.round_name ?? '-') },
    { label: 'Stage', value: String(summary?.stage ?? '-') },
    { label: 'Target', value: fmtRupees(target) },
    { label: 'Soft commits', value: fmtRupees(softCommit) },
    { label: 'Wired', value: fmtRupees(wired) },
    { label: 'Remaining', value: fmtRupees(remaining) },
    { label: '% committed', value: `${pctCommitted}%` },
    { label: '% wired', value: `${pctWired}%` },
    { label: 'Days open', value: `${daysOpen}d` },
    { label: 'Days to close', value: daysToClose === null ? '-' : `${daysToClose}d` },
    { label: 'Investors', value: String(investorCount) },
    { label: 'Meetings this week', value: String(meetingsCount) },
    { label: 'Next 48h', value: String(next48h) },
    { label: 'Hot (>=80)', value: String(hotCount) },
    { label: 'Term sheets', value: String(termSheetCount) },
    { label: 'Avg heat (top)', value: String(avgHeat) },
  ];

  const meetingCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => String(r.investor_name ?? '-') },
    { key: 'investor_firm', header: 'Firm', render: (r: any) => String(r.investor_firm ?? '-') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '-') },
    { key: 'heat_score', header: 'Heat', render: (r: any) => String(r.heat_score ?? '-') },
    { key: 'next_meeting_at', header: 'When', render: (r: any) => r.next_meeting_at ? new Date(r.next_meeting_at).toLocaleString('en-IN') : '-' },
    { key: 'hours_until', header: 'Hours', render: (r: any) => `${r.hours_until ?? '-'}h` },
  ];

  const hottestCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => String(r.investor_name ?? '-') },
    { key: 'investor_firm', header: 'Firm', render: (r: any) => String(r.investor_firm ?? '-') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '-') },
    { key: 'heat_score', header: 'Heat', render: (r: any) => String(r.heat_score ?? '-') },
    { key: 'soft_commit_rupees', header: 'Soft commit', render: (r: any) => fmtRupees(Number(r.soft_commit_rupees ?? 0)) },
    { key: 'wired_rupees', header: 'Wired', render: (r: any) => fmtRupees(Number(r.wired_rupees ?? 0)) },
    { key: 'days_since_touch', header: 'Last touch', render: (r: any) => `${r.days_since_touch ?? '-'}d ago` },
  ];

  const heatmapCols: Column<any>[] = [
    { key: 'bucket_date', header: 'Date', render: (r: any) => String(r.bucket_date ?? '-') },
    { key: 'hour_bucket', header: 'Slot', render: (r: any) => String(r.hour_bucket ?? '-') },
    { key: 'meeting_count', header: 'Meetings', render: (r: any) => String(r.meeting_count ?? 0) },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Stage', render: (r: any) => String(r.status ?? '-') },
    { key: 'investor_count', header: 'Count', render: (r: any) => String(r.investor_count ?? 0) },
    { key: 'soft_commit_total', header: 'Soft commit', render: (r: any) => fmtRupees(Number(r.soft_commit_total ?? 0)) },
    { key: 'wired_total', header: 'Wired', render: (r: any) => fmtRupees(Number(r.wired_total ?? 0)) },
    { key: 'avg_heat', header: 'Avg heat', render: (r: any) => String(r.avg_heat ?? '-') },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>Fundraise War Room</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>Real-time visibility during active raise. r1536.</p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ padding: 14, border: '1px solid #e5e7eb', borderRadius: 8, background: '#fff' }}>
            <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.4 }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Meetings this week</h2>
        <DataTable columns={meetingCols} rows={meetings} rowKey={(r: any) => r.investor_id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Hottest investors</h2>
        <DataTable columns={hottestCols} rows={hottest} rowKey={(r: any) => r.investor_id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Schedule heatmap (next 14 days)</h2>
        <DataTable columns={heatmapCols} rows={heatmap} rowKey={(r: any) => `${r.bucket_date}-${r.hour_bucket}`} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Funnel by status</h2>
        <DataTable columns={funnelCols} rows={funnel} rowKey={(r: any) => String(r.status)} />
      </section>
    </div>
  );
}
