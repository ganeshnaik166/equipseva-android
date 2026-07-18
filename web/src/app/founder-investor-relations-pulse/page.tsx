import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function fmtDate(v: string | null | undefined) {
  if (!v) return '-';
  try {
    return new Date(v).toLocaleDateString('en-IN', { year: 'numeric', month: 'short', day: '2-digit' });
  } catch {
    return String(v);
  }
}

function sentimentBadge(s: string) {
  const color =
    s === 'very_positive' ? '#16a34a' :
    s === 'positive' ? '#65a30d' :
    s === 'neutral' ? '#6b7280' :
    s === 'concerned' ? '#f59e0b' :
    s === 'negative' ? '#dc2626' : '#6b7280';
  return (
    <span style={{ background: color, color: '#fff', padding: '2px 8px', borderRadius: 4, fontSize: 12, fontWeight: 600 }}>
      {s}
    </span>
  );
}

export default async function FounderInvestorRelationsPulsePage() {
  const supabase = await getSupabaseServerClient();

  const [
    pulseRes,
    boardSendsRes,
    overdueRes,
    sentimentRes,
    asksRes,
    milestonesRes,
    engagementRes,
  ] = await Promise.all([
    supabase.rpc('list_investor_pulse_r2429'),
    supabase.rpc('list_board_pack_sends_r2429'),
    supabase.rpc('overdue_pulse_r2429'),
    supabase.rpc('sentiment_breakdown_r2429'),
    supabase.rpc('open_asks_r2429'),
    supabase.rpc('upcoming_milestones_r2429'),
    supabase.rpc('board_pack_engagement_r2429'),
  ]);

  const pulse = (pulseRes.data ?? []) as any[];
  const boardSends = (boardSendsRes.data ?? []) as any[];
  const overdue = (overdueRes.data ?? []) as any[];
  const sentiment = (sentimentRes.data ?? []) as any[];
  const asks = (asksRes.data ?? []) as any[];
  const milestones = (milestonesRes.data ?? []) as any[];
  const engagement = (engagementRes.data ?? []) as any[];

  const pulseCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => <strong>{r.investor_name}</strong> },
    { key: 'firm_name', header: 'Firm', render: (r: any) => r.firm_name },
    { key: 'last_touch_at', header: 'Last Touch', render: (r: any) => fmtDate(r.last_touch_at) },
    { key: 'touch_kind', header: 'Kind', render: (r: any) => r.touch_kind },
    { key: 'gap_days', header: 'Gap (d)', render: (r: any) => r.gap_days },
    { key: 'cadence_target_days', header: 'Target (d)', render: (r: any) => r.cadence_target_days },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => sentimentBadge(r.sentiment) },
    { key: 'board_seat', header: 'Board', render: (r: any) => (r.board_seat ? 'Yes' : 'No') },
    { key: 'next_milestone', header: 'Next Milestone', render: (r: any) => r.next_milestone ?? '-' },
  ];

  const boardSendsCols: Column<any>[] = [
    { key: 'quarter', header: 'Quarter', render: (r: any) => <strong>{r.quarter}</strong> },
    { key: 'sent_at', header: 'Sent', render: (r: any) => fmtDate(r.sent_at) },
    { key: 'recipient_count', header: 'Recipients', render: (r: any) => r.recipient_count },
    { key: 'viewed_count', header: 'Viewed', render: (r: any) => r.viewed_count },
    { key: 'downloaded_count', header: 'Downloaded', render: (r: any) => r.downloaded_count },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => <strong>{r.investor_name}</strong> },
    { key: 'firm_name', header: 'Firm', render: (r: any) => r.firm_name },
    { key: 'gap_days', header: 'Gap (d)', render: (r: any) => r.gap_days },
    { key: 'cadence_target_days', header: 'Target (d)', render: (r: any) => r.cadence_target_days },
    { key: 'days_over', header: 'Days Over', render: (r: any) => <span style={{ color: '#dc2626', fontWeight: 700 }}>{r.days_over}</span> },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => sentimentBadge(r.sentiment) },
    { key: 'board_seat', header: 'Board', render: (r: any) => (r.board_seat ? 'Yes' : 'No') },
  ];

  const sentimentCols: Column<any>[] = [
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => sentimentBadge(r.sentiment) },
    { key: 'investor_count', header: 'Investors', render: (r: any) => r.investor_count },
    { key: 'board_seat_count', header: 'Board Seats', render: (r: any) => r.board_seat_count },
    { key: 'avg_gap_days', header: 'Avg Gap (d)', render: (r: any) => r.avg_gap_days },
  ];

  const asksCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => <strong>{r.investor_name}</strong> },
    { key: 'firm_name', header: 'Firm', render: (r: any) => r.firm_name },
    { key: 'open_ask', header: 'Open Ask', render: (r: any) => r.open_ask },
    { key: 'open_ask_due_at', header: 'Due', render: (r: any) => fmtDate(r.open_ask_due_at) },
    { key: 'days_until_due', header: 'Days Until', render: (r: any) => {
        const d = r.days_until_due;
        const color = d < 0 ? '#dc2626' : d <= 7 ? '#f59e0b' : '#16a34a';
        return <span style={{ color, fontWeight: 600 }}>{d}</span>;
      } },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => sentimentBadge(r.sentiment) },
  ];

  const milestoneCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => <strong>{r.investor_name}</strong> },
    { key: 'firm_name', header: 'Firm', render: (r: any) => r.firm_name },
    { key: 'next_milestone', header: 'Milestone', render: (r: any) => r.next_milestone },
    { key: 'next_milestone_due_at', header: 'Due', render: (r: any) => fmtDate(r.next_milestone_due_at) },
    { key: 'days_until', header: 'Days Until', render: (r: any) => r.days_until },
    { key: 'board_seat', header: 'Board', render: (r: any) => (r.board_seat ? 'Yes' : 'No') },
  ];

  const engagementCols: Column<any>[] = [
    { key: 'quarter', header: 'Quarter', render: (r: any) => <strong>{r.quarter}</strong> },
    { key: 'sent_at', header: 'Sent', render: (r: any) => fmtDate(r.sent_at) },
    { key: 'recipient_count', header: 'Recipients', render: (r: any) => r.recipient_count },
    { key: 'view_rate_pct', header: 'View Rate %', render: (r: any) => `${r.view_rate_pct}%` },
    { key: 'download_rate_pct', header: 'Download Rate %', render: (r: any) => `${r.download_rate_pct}%` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto', fontFamily: 'system-ui, -apple-system, sans-serif' }}>
      <h1 style={{ fontSize: 28, fontWeight: 800, marginBottom: 4 }}>Founder — Investor Relations Pulse</h1>
      <p style={{ color: '#6b7280', marginBottom: 24 }}>
        Investor × last touch × cadence × sentiment × open asks × board pack engagement
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12 }}>Overdue Pulse (gap &gt; target)</h2>
        <DataTable
          rows={overdue}
          columns={overdueCols}
          emptyMessage="No investors overdue."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12 }}>Sentiment Breakdown</h2>
        <DataTable
          rows={sentiment}
          columns={sentimentCols}
          emptyMessage="No sentiment data."
          rowKey={(r: any, i: number) => String(r.sentiment ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12 }}>Open Asks</h2>
        <DataTable
          rows={asks}
          columns={asksCols}
          emptyMessage="No open asks."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12 }}>Upcoming Milestones</h2>
        <DataTable
          rows={milestones}
          columns={milestoneCols}
          emptyMessage="No upcoming milestones."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12 }}>Full Investor Pulse Log</h2>
        <DataTable
          rows={pulse}
          columns={pulseCols}
          emptyMessage="No investor pulse entries."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12 }}>Board Pack Engagement</h2>
        <DataTable
          rows={engagement}
          columns={engagementCols}
          emptyMessage="No board pack sends."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12 }}>Board Pack Sends Log</h2>
        <DataTable
          rows={boardSends}
          columns={boardSendsCols}
          emptyMessage="No board pack sends."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
