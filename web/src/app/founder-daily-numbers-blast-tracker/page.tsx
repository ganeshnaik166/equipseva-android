import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [summary, recent, openRate, lowEng, commentary, channelMix, failed] = await Promise.all([
    sb.rpc('r2249_blast_summary'),
    sb.rpc('r2249_recent_blasts'),
    sb.rpc('r2249_open_rate_by_role'),
    sb.rpc('r2249_low_engagement_recipients'),
    sb.rpc('r2249_commentary_log'),
    sb.rpc('r2249_channel_mix'),
    sb.rpc('r2249_failed_blast_alerts'),
  ]);

  const s = (summary.data && summary.data[0]) || {
    total_blasts: 0, sent_blasts: 0, failed_blasts: 0, skipped_blasts: 0,
    total_revenue_rupees: 0, avg_nps: null,
  };

  const recentCols: Column<any>[] = [
    { key: 'blast_date', header: 'Date', render: (r) => String(r.blast_date) },
    { key: 'subject', header: 'Subject', render: (r) => r.subject },
    { key: 'revenue_rupees', header: 'Revenue', render: (r) => '₹' + Number(r.revenue_rupees).toLocaleString('en-IN') },
    { key: 'jobs_completed', header: 'Done', render: (r) => String(r.jobs_completed) },
    { key: 'jobs_open', header: 'Open', render: (r) => String(r.jobs_open) },
    { key: 'nps_score', header: 'NPS', render: (r) => r.nps_score == null ? '—' : String(r.nps_score) },
    { key: 'channel', header: 'Channel', render: (r) => r.channel },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'recipient_count', header: 'Sent', render: (r) => String(r.recipient_count) },
    { key: 'opened_count', header: 'Opened', render: (r) => String(r.opened_count) },
  ];

  const openCols: Column<any>[] = [
    { key: 'recipient_role', header: 'Role', render: (r) => r.recipient_role },
    { key: 'total', header: 'Total', render: (r) => String(r.total) },
    { key: 'opened', header: 'Opened', render: (r) => String(r.opened) },
    { key: 'open_rate_pct', header: 'Open %', render: (r) => r.open_rate_pct == null ? '—' : String(r.open_rate_pct) + '%' },
    { key: 'avg_clicks', header: 'Avg clicks', render: (r) => r.avg_clicks == null ? '—' : String(r.avg_clicks) },
  ];

  const lowCols: Column<any>[] = [
    { key: 'recipient_email', header: 'Email', render: (r) => r.recipient_email },
    { key: 'recipient_role', header: 'Role', render: (r) => r.recipient_role },
    { key: 'total_blasts', header: 'Sent', render: (r) => String(r.total_blasts) },
    { key: 'opened_blasts', header: 'Opened', render: (r) => String(r.opened_blasts) },
    { key: 'open_rate_pct', header: 'Open %', render: (r) => r.open_rate_pct == null ? '—' : String(r.open_rate_pct) + '%' },
  ];

  const commentaryCols: Column<any>[] = [
    { key: 'blast_date', header: 'Date', render: (r) => String(r.blast_date) },
    { key: 'subject', header: 'Subject', render: (r) => r.subject },
    { key: 'founder_commentary', header: 'Founder note', render: (r) => r.founder_commentary },
    { key: 'status', header: 'Status', render: (r) => r.status },
  ];

  const channelCols: Column<any>[] = [
    { key: 'channel', header: 'Channel', render: (r) => r.channel },
    { key: 'blast_count', header: 'Blasts', render: (r) => String(r.blast_count) },
    { key: 'avg_open_rate_pct', header: 'Avg open %', render: (r) => r.avg_open_rate_pct == null ? '—' : String(r.avg_open_rate_pct) + '%' },
  ];

  const failedCols: Column<any>[] = [
    { key: 'blast_date', header: 'Date', render: (r) => String(r.blast_date) },
    { key: 'subject', header: 'Subject', render: (r) => r.subject },
    { key: 'channel', header: 'Channel', render: (r) => r.channel },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'sent_at', header: 'Attempted', render: (r) => new Date(r.sent_at).toLocaleString('en-IN') },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Daily Numbers Blast Tracker</h1>
      <p style={{ color: '#666', marginBottom: 16 }}>
        Morning numbers auto-sent to team. Track delivery, opens, founder commentary across last 30 days.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 12, marginBottom: 24 }}>
        <Card label="Total (30d)" value={String(s.total_blasts)} />
        <Card label="Sent" value={String(s.sent_blasts)} />
        <Card label="Failed" value={String(s.failed_blasts)} />
        <Card label="Skipped" value={String(s.skipped_blasts)} />
        <Card label="Revenue blasted" value={'₹' + Number(s.total_revenue_rupees).toLocaleString('en-IN')} />
        <Card label="Avg NPS" value={s.avg_nps == null ? '—' : String(s.avg_nps)} hint="target > 55" />
      </div>

      <Section title="Recent blasts (30d)">
        <DataTable columns={recentCols} rows={recent.data || []} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Open rate by role">
        <DataTable columns={openCols} rows={openRate.data || []} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Low engagement recipients (open rate < 50%)">
        <DataTable columns={lowCols} rows={lowEng.data || []} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Founder commentary log">
        <DataTable columns={commentaryCols} rows={commentary.data || []} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Channel mix (sent only)">
        <DataTable columns={channelCols} rows={channelMix.data || []} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Failed & skipped blasts">
        <DataTable columns={failedCols} rows={failed.data || []} rowKey={(_, i) => String(i)} />
      </Section>
    </div>
  );
}

function Card({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase' }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700, marginTop: 4 }}>{value}</div>
      {hint ? <div style={{ fontSize: 11, color: '#9ca3af', marginTop: 2 }}>{hint}</div> : null}
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div style={{ marginBottom: 24 }}>
      <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>{title}</h2>
      {children}
    </div>
  );
}
