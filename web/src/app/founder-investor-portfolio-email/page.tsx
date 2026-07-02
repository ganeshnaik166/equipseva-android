import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

export default async function FounderInvestorPortfolioEmailPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let campaigns: any[] = [];
  let kpiAutofill: any[] = [];
  let recentReplies: any[] = [];
  let engagement: any = {};
  let topInvestors: any[] = [];
  let monthlyTrend: any[] = [];

  try {
    const r = await sb.rpc('founder_invemail_recent_campaigns');
    campaigns = (r.data as any[]) ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_invemail_kpi_autofill');
    kpiAutofill = (r.data as any[]) ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_invemail_recent_replies');
    recentReplies = (r.data as any[]) ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_invemail_engagement_summary');
    engagement = ((r.data as any[]) ?? [])[0] ?? {};
  } catch {}
  try {
    const r = await sb.rpc('founder_invemail_top_engaged_investors');
    topInvestors = (r.data as any[]) ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_invemail_monthly_trend');
    monthlyTrend = (r.data as any[]) ?? [];
  } catch {}

  const sentCampaigns = campaigns.filter((c: any) => c.status === 'sent').length;
  const draftCampaigns = campaigns.filter((c: any) => c.status === 'draft').length;
  const totalOpens = campaigns.reduce((s: number, c: any) => s + (Number(c.opens_count) || 0), 0);
  const totalClicks = campaigns.reduce((s: number, c: any) => s + (Number(c.clicks_count) || 0), 0);
  const totalReplies = campaigns.reduce((s: number, c: any) => s + (Number(c.replies_count) || 0), 0);
  const totalSends = campaigns.reduce((s: number, c: any) => s + (Number(c.sent_count) || 0), 0);
  const positiveReplies = recentReplies.filter((r: any) => r.reply_category === 'positive').length;
  const introRequests = recentReplies.filter((r: any) => r.reply_category === 'intro_request').length;
  const passes = recentReplies.filter((r: any) => r.reply_category === 'pass').length;
  const questions = recentReplies.filter((r: any) => r.reply_category === 'question').length;

  const kpis: Kpi[] = [
    { label: 'Campaigns total', value: String(campaigns.length) },
    { label: 'Sent', value: String(sentCampaigns) },
    { label: 'Drafts', value: String(draftCampaigns) },
    { label: 'Total sends', value: String(totalSends) },
    { label: 'Total opens', value: String(totalOpens) },
    { label: 'Total clicks', value: String(totalClicks) },
    { label: 'Total replies', value: String(totalReplies) },
    { label: 'Open rate %', value: String(engagement?.open_rate_pct ?? '0') },
    { label: 'Reply rate %', value: String(engagement?.reply_rate_pct ?? '0') },
    { label: 'Unique opens', value: String(engagement?.unique_opens ?? '0') },
    { label: 'Positive replies', value: String(positiveReplies) },
    { label: 'Intro requests', value: String(introRequests) },
    { label: 'Passes', value: String(passes) },
    { label: 'Questions', value: String(questions) },
    { label: 'Top investors', value: String(topInvestors.length) },
    { label: 'KPI autofill rows', value: String(kpiAutofill.length) },
  ];

  const campaignCols: Column<any>[] = [
    { key: 'subject', header: 'Subject', render: (r: any) => r.subject ?? '—' },
    { key: 'period_month', header: 'Period', render: (r: any) => r.period_month ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'recipients_count', header: 'Recipients', render: (r: any) => String(r.recipients_count ?? 0) },
    { key: 'opens_count', header: 'Opens', render: (r: any) => String(r.opens_count ?? 0) },
    { key: 'clicks_count', header: 'Clicks', render: (r: any) => String(r.clicks_count ?? 0) },
    { key: 'replies_count', header: 'Replies', render: (r: any) => String(r.replies_count ?? 0) },
    { key: 'sent_at', header: 'Sent at', render: (r: any) => (r.sent_at ? new Date(r.sent_at).toLocaleString() : '—') },
  ];

  const kpiCols: Column<any>[] = [
    { key: 'metric', header: 'Metric', render: (r: any) => r.metric ?? '—' },
    { key: 'value_text', header: 'Value', render: (r: any) => r.value_text ?? '—' },
  ];

  const repliesCols: Column<any>[] = [
    { key: 'campaign_subject', header: 'Campaign', render: (r: any) => r.campaign_subject ?? '—' },
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? r.investor_email ?? '—' },
    { key: 'investor_firm', header: 'Firm', render: (r: any) => r.investor_firm ?? '—' },
    { key: 'reply_category', header: 'Category', render: (r: any) => r.reply_category ?? '—' },
    { key: 'reply_snippet', header: 'Snippet', render: (r: any) => r.reply_snippet ?? '—' },
    { key: 'replied_at', header: 'Replied', render: (r: any) => (r.replied_at ? new Date(r.replied_at).toLocaleString() : '—') },
  ];

  const topCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? r.investor_email ?? '—' },
    { key: 'investor_firm', header: 'Firm', render: (r: any) => r.investor_firm ?? '—' },
    { key: 'sends_n', header: 'Sends', render: (r: any) => String(r.sends_n ?? 0) },
    { key: 'opens_n', header: 'Opens', render: (r: any) => String(r.opens_n ?? 0) },
    { key: 'clicks_n', header: 'Clicks', render: (r: any) => String(r.clicks_n ?? 0) },
    { key: 'replies_n', header: 'Replies', render: (r: any) => String(r.replies_n ?? 0) },
    { key: 'last_seen_at', header: 'Last seen', render: (r: any) => (r.last_seen_at ? new Date(r.last_seen_at).toLocaleString() : '—') },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label ?? '—' },
    { key: 'campaigns_n', header: 'Campaigns', render: (r: any) => String(r.campaigns_n ?? 0) },
    { key: 'sends_n', header: 'Sends', render: (r: any) => String(r.sends_n ?? 0) },
    { key: 'opens_n', header: 'Opens', render: (r: any) => String(r.opens_n ?? 0) },
    { key: 'replies_n', header: 'Replies', render: (r: any) => String(r.replies_n ?? 0) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 4 }}>Investor portfolio email-out</h1>
      <p style={{ color: '#666', marginBottom: 16 }}>
        Monthly investor update composer with KPI auto-fill, per-investor send log, open/click tracking, and reply categorization.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {kpis.map((k, i) => (
          <div key={i} style={{ border: '1px solid #eee', borderRadius: 8, padding: 12 }}>
            <div style={{ color: '#666', fontSize: 12 }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 700 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <h2 style={{ fontSize: 16, fontWeight: 700, margin: '16px 0 8px' }}>Recent campaigns</h2>
      <DataTable rows={campaigns} columns={campaignCols} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 16, fontWeight: 700, margin: '24px 0 8px' }}>KPI auto-fill (this period)</h2>
      <DataTable rows={kpiAutofill} columns={kpiCols} rowKey={(r: any) => r.metric} />

      <h2 style={{ fontSize: 16, fontWeight: 700, margin: '24px 0 8px' }}>Recent replies</h2>
      <DataTable rows={recentReplies} columns={repliesCols} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 16, fontWeight: 700, margin: '24px 0 8px' }}>Top engaged investors</h2>
      <DataTable rows={topInvestors} columns={topCols} rowKey={(r: any) => r.investor_email} />

      <h2 style={{ fontSize: 16, fontWeight: 700, margin: '24px 0 8px' }}>Monthly trend (12mo)</h2>
      <DataTable rows={monthlyTrend} columns={trendCols} rowKey={(r: any) => r.month_label} />
    </main>
  );
}
