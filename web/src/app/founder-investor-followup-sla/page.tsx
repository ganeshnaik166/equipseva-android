import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

async function safeRpc(sb: any, name: string, args?: any) {
  try {
    const { data, error } = await sb.rpc(name, args ?? {});
    if (error) return [];
    return Array.isArray(data) ? data : (data ? [data] : []);
  } catch {
    return [];
  }
}

function fmtNum(n: any, digits = 1): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (!isFinite(v)) return '—';
  return v.toFixed(digits);
}

function fmtInt(n: any): string {
  if (n === null || n === undefined) return '—';
  return String(Number(n) | 0);
}

function fmtTs(t: any): string {
  if (!t) return '—';
  try { return new Date(t).toLocaleString('en-IN'); } catch { return String(t); }
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const summary = await safeRpc(sb, 'founder_investor_sla_summary');
  const overdue = await safeRpc(sb, 'founder_investor_overdue_list');
  const debt = await safeRpc(sb, 'founder_investor_debt_per_investor');
  const dueSoon = await safeRpc(sb, 'founder_investor_due_soon');
  const weekly = await safeRpc(sb, 'founder_investor_weekly_clearance_log');
  const channel = await safeRpc(sb, 'founder_investor_channel_mix');
  const openList = await safeRpc(sb, 'founder_investor_open_interactions');

  const s = summary[0] ?? {};
  const totalOpen = Number(s.total_open ?? 0);
  const overdueCount = Number(s.overdue_count ?? 0);
  const due24 = Number(s.due_24h ?? 0);
  const cleared7d = Number(s.cleared_7d ?? 0);
  const medianClear = s.median_clear_hours;
  const oldestOver = s.oldest_overdue_hours;
  const uniqInv = Number(s.unique_investors ?? 0);

  const overdueRatio = totalOpen > 0 ? (overdueCount / totalOpen) * 100 : 0;
  const investorsWithDebt = debt.length;
  const investorsOverdue = debt.filter((d: any) => Number(d.overdue_count ?? 0) > 0).length;
  const worstInvestor = debt[0]?.investor_name ?? '—';
  const worstInvestorDebt = Number(debt[0]?.open_count ?? 0);
  const dueSoonCount = dueSoon.length;
  const last4WeeksCleared = weekly.slice(0, 4).reduce((a: number, w: any) => a + Number(w.cleared_count ?? 0), 0);
  const last4WeeksOpened = weekly.slice(0, 4).reduce((a: number, w: any) => a + Number(w.opened_count ?? 0), 0);
  const clearanceRatio = last4WeeksOpened > 0 ? (last4WeeksCleared / last4WeeksOpened) * 100 : 0;
  const topChannel = channel[0]?.channel ?? '—';
  const channelCount = channel.length;

  const kpis: Kpi[] = [
    { label: 'Open interactions', value: fmtInt(totalOpen) },
    { label: 'Overdue', value: fmtInt(overdueCount) },
    { label: 'Due in 24h', value: fmtInt(due24) },
    { label: 'Cleared 7d', value: fmtInt(cleared7d) },
    { label: 'Median clear hrs', value: fmtNum(medianClear) },
    { label: 'Oldest overdue hrs', value: fmtNum(oldestOver) },
    { label: 'Unique investors', value: fmtInt(uniqInv) },
    { label: 'Overdue %', value: fmtNum(overdueRatio) + '%' },
    { label: 'Investors w/ debt', value: fmtInt(investorsWithDebt) },
    { label: 'Investors overdue', value: fmtInt(investorsOverdue) },
    { label: 'Worst investor', value: String(worstInvestor) },
    { label: 'Worst investor debt', value: fmtInt(worstInvestorDebt) },
    { label: 'Due-soon queue', value: fmtInt(dueSoonCount) },
    { label: 'Clear ratio 4w %', value: fmtNum(clearanceRatio) + '%' },
    { label: 'Top channel', value: String(topChannel) },
    { label: 'Channels used', value: fmtInt(channelCount) },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => String(r.investor_name ?? '—') },
    { key: 'investor_firm', header: 'Firm', render: (r: any) => String(r.investor_firm ?? '—') },
    { key: 'channel', header: 'Channel', render: (r: any) => String(r.channel ?? '—') },
    { key: 'topic', header: 'Topic', render: (r: any) => String(r.topic ?? '—') },
    { key: 'contacted_at', header: 'Contacted', render: (r: any) => fmtTs(r.contacted_at) },
    { key: 'followup_due_at', header: 'Due', render: (r: any) => fmtTs(r.followup_due_at) },
    { key: 'hours_overdue', header: 'Hrs overdue', render: (r: any) => fmtNum(r.hours_overdue) },
  ];

  const debtCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => String(r.investor_name ?? '—') },
    { key: 'investor_firm', header: 'Firm', render: (r: any) => String(r.investor_firm ?? '—') },
    { key: 'open_count', header: 'Open', render: (r: any) => fmtInt(r.open_count) },
    { key: 'overdue_count', header: 'Overdue', render: (r: any) => fmtInt(r.overdue_count) },
    { key: 'oldest_open_hours', header: 'Oldest hrs', render: (r: any) => fmtNum(r.oldest_open_hours) },
    { key: 'last_contact', header: 'Last contact', render: (r: any) => fmtTs(r.last_contact) },
  ];

  const dueSoonCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => String(r.investor_name ?? '—') },
    { key: 'channel', header: 'Channel', render: (r: any) => String(r.channel ?? '—') },
    { key: 'topic', header: 'Topic', render: (r: any) => String(r.topic ?? '—') },
    { key: 'followup_due_at', header: 'Due', render: (r: any) => fmtTs(r.followup_due_at) },
    { key: 'hours_until_due', header: 'Hrs left', render: (r: any) => fmtNum(r.hours_until_due) },
  ];

  const weeklyCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '—') },
    { key: 'cleared_count', header: 'Cleared', render: (r: any) => fmtInt(r.cleared_count) },
    { key: 'opened_count', header: 'Opened', render: (r: any) => fmtInt(r.opened_count) },
    { key: 'overdue_carry', header: 'Overdue carry', render: (r: any) => fmtInt(r.overdue_carry) },
    { key: 'median_hours', header: 'Median hrs', render: (r: any) => fmtNum(r.median_hours) },
  ];

  const channelCols: Column<any>[] = [
    { key: 'channel', header: 'Channel', render: (r: any) => String(r.channel ?? '—') },
    { key: 'total_count', header: 'Total', render: (r: any) => fmtInt(r.total_count) },
    { key: 'open_count', header: 'Open', render: (r: any) => fmtInt(r.open_count) },
    { key: 'overdue_count', header: 'Overdue', render: (r: any) => fmtInt(r.overdue_count) },
    { key: 'median_clear_hours', header: 'Median clear hrs', render: (r: any) => fmtNum(r.median_clear_hours) },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 6 }}>Investor follow-up SLA tracker</h1>
      <p style={{ color: '#555', marginBottom: 18 }}>
        Every investor touch starts a clock. Overdue {">"} 0h = founder debt. Clear weekly.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
            <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase' }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 18, marginBottom: 8 }}>Overdue ({overdue.length})</h2>
      <DataTable<any> rows={overdue} columns={overdueCols} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Founder-debt per investor</h2>
      <DataTable<any> rows={debt} columns={debtCols} rowKey={(r: any) => r.investor_name} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Due in next 48h</h2>
      <DataTable<any> rows={dueSoon} columns={dueSoonCols} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Weekly clearance log</h2>
      <DataTable<any> rows={weekly} columns={weeklyCols} rowKey={(r: any) => r.week_start} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Channel mix</h2>
      <DataTable<any> rows={channel} columns={channelCols} rowKey={(r: any) => r.channel} />

      <p style={{ marginTop: 24, fontSize: 12, color: '#6b7280' }}>
        SLA defaults: email 48h, call 24h, meeting 24h. Overdue when due {"<"} now and not cleared. {openList.length} total open rows tracked.
      </p>
    </div>
  );
}
