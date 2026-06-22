import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = {
  total_tickets: number;
  deflected_tickets: number;
  deflection_rate_pct: number | null;
  total_cost_saved_rupees: number;
  avg_csat_self_help: number | null;
  avg_csat_human: number | null;
  csat_parity_gap: number | null;
};

type ChannelRow = {
  channel: string;
  ticket_count: number;
  resolved_count: number;
  avg_resolution_minutes: number | null;
  total_cost_saved: number;
  avg_csat: number | null;
};

type IntentRow = {
  intent_category: string;
  total_tickets: number;
  deflected_count: number;
  deflection_rate_pct: number | null;
  escalation_rate_pct: number | null;
};

type KbRow = {
  article_title: string;
  intent_category: string;
  views_count: number;
  helpful_pct: number | null;
  deflections_attributed: number;
  status: string;
};

type KbStaleRow = {
  article_title: string;
  intent_category: string;
  helpful_pct: number | null;
  unhelpful_votes: number;
  days_since_update: number;
  status: string;
};

type TrendRow = {
  day_date: string;
  total_tickets: number;
  deflected_count: number;
  cost_saved: number;
};

type EscalationRow = {
  ticket_ref: string;
  channel: string;
  intent_category: string;
  bot_confidence_score: number | null;
  opened_at: string;
  resolution_minutes: number | null;
  csat_score: number | null;
};

function fmtMoney(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN', { maximumFractionDigits: 0 });
}

function fmtPct(n: number | null | undefined): string {
  if (n == null) return '-';
  return `${Number(n).toFixed(1)}%`;
}

function fmtNum(n: number | null | undefined, digits = 2): string {
  if (n == null) return '-';
  return Number(n).toFixed(digits);
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [kpis, channels, intents, topKb, staleKb, trend, escalations] = await Promise.all([
    sb.rpc('founder_deflection_kpis_r2256'),
    sb.rpc('founder_deflection_by_channel_r2256'),
    sb.rpc('founder_deflection_by_intent_r2256'),
    sb.rpc('founder_deflection_top_kb_r2256'),
    sb.rpc('founder_deflection_kb_needs_update_r2256'),
    sb.rpc('founder_deflection_daily_trend_r2256'),
    sb.rpc('founder_deflection_recent_escalations_r2256'),
  ]);

  const kpi: KpiRow | null = (kpis.data as KpiRow[] | null)?.[0] ?? null;
  const channelRows: ChannelRow[] = (channels.data as ChannelRow[] | null) ?? [];
  const intentRows: IntentRow[] = (intents.data as IntentRow[] | null) ?? [];
  const topKbRows: KbRow[] = (topKb.data as KbRow[] | null) ?? [];
  const staleKbRows: KbStaleRow[] = (staleKb.data as KbStaleRow[] | null) ?? [];
  const trendRows: TrendRow[] = (trend.data as TrendRow[] | null) ?? [];
  const escalationRows: EscalationRow[] = (escalations.data as EscalationRow[] | null) ?? [];

  const channelCols: Column<ChannelRow>[] = [
    { key: 'channel', header: 'Channel', render: (r) => r.channel },
    { key: 'ticket_count', header: 'Tickets', render: (r) => r.ticket_count },
    { key: 'resolved_count', header: 'Resolved', render: (r) => r.resolved_count },
    { key: 'avg_resolution_minutes', header: 'Avg min', render: (r) => fmtNum(r.avg_resolution_minutes, 1) },
    { key: 'total_cost_saved', header: 'Saved', render: (r) => fmtMoney(r.total_cost_saved) },
    { key: 'avg_csat', header: 'CSAT', render: (r) => fmtNum(r.avg_csat, 2) },
  ];

  const intentCols: Column<IntentRow>[] = [
    { key: 'intent_category', header: 'Intent', render: (r) => r.intent_category },
    { key: 'total_tickets', header: 'Tickets', render: (r) => r.total_tickets },
    { key: 'deflected_count', header: 'Deflected', render: (r) => r.deflected_count },
    { key: 'deflection_rate_pct', header: 'Deflection %', render: (r) => fmtPct(r.deflection_rate_pct) },
    { key: 'escalation_rate_pct', header: 'Escalation %', render: (r) => fmtPct(r.escalation_rate_pct) },
  ];

  const topKbCols: Column<KbRow>[] = [
    { key: 'article_title', header: 'Article', render: (r) => r.article_title },
    { key: 'intent_category', header: 'Intent', render: (r) => r.intent_category },
    { key: 'views_count', header: 'Views', render: (r) => r.views_count },
    { key: 'helpful_pct', header: 'Helpful %', render: (r) => fmtPct(r.helpful_pct) },
    { key: 'deflections_attributed', header: 'Deflections', render: (r) => r.deflections_attributed },
    { key: 'status', header: 'Status', render: (r) => r.status },
  ];

  const staleKbCols: Column<KbStaleRow>[] = [
    { key: 'article_title', header: 'Article', render: (r) => r.article_title },
    { key: 'intent_category', header: 'Intent', render: (r) => r.intent_category },
    { key: 'helpful_pct', header: 'Helpful %', render: (r) => fmtPct(r.helpful_pct) },
    { key: 'unhelpful_votes', header: 'Unhelpful', render: (r) => r.unhelpful_votes },
    { key: 'days_since_update', header: 'Days stale', render: (r) => r.days_since_update },
    { key: 'status', header: 'Status', render: (r) => r.status },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'day_date', header: 'Date', render: (r) => r.day_date },
    { key: 'total_tickets', header: 'Tickets', render: (r) => r.total_tickets },
    { key: 'deflected_count', header: 'Deflected', render: (r) => r.deflected_count },
    { key: 'cost_saved', header: 'Saved', render: (r) => fmtMoney(r.cost_saved) },
  ];

  const escCols: Column<EscalationRow>[] = [
    { key: 'ticket_ref', header: 'Ticket', render: (r) => r.ticket_ref },
    { key: 'channel', header: 'Channel', render: (r) => r.channel },
    { key: 'intent_category', header: 'Intent', render: (r) => r.intent_category },
    { key: 'bot_confidence_score', header: 'Bot conf', render: (r) => fmtNum(r.bot_confidence_score, 3) },
    { key: 'opened_at', header: 'Opened', render: (r) => new Date(r.opened_at).toLocaleString('en-IN') },
    { key: 'resolution_minutes', header: 'Min', render: (r) => r.resolution_minutes ?? '-' },
    { key: 'csat_score', header: 'CSAT', render: (r) => r.csat_score ?? '-' },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1280px', margin: '0 auto' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '6px' }}>
          Customer Service Deflection Tracker
        </h1>
        <p style={{ color: '#666', fontSize: '14px' }}>
          Self-help vs human-handled tickets, cost saved, and CSAT parity (last 30 days)
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '12px', marginBottom: '28px' }}>
        <KpiCard label="Total tickets" value={String(kpi?.total_tickets ?? 0)} hint="30d window" />
        <KpiCard label="Deflected" value={String(kpi?.deflected_tickets ?? 0)} hint="self-help + bot" />
        <KpiCard label="Deflection rate" value={fmtPct(kpi?.deflection_rate_pct)} hint="target 60%+" />
        <KpiCard label="Cost saved" value={fmtMoney(kpi?.total_cost_saved_rupees)} hint="agent minutes saved" />
        <KpiCard label="CSAT self-help" value={fmtNum(kpi?.avg_csat_self_help)} hint="bot + KB" />
        <KpiCard label="CSAT human" value={fmtNum(kpi?.avg_csat_human)} hint="agent handled" />
        <KpiCard label="Parity gap" value={fmtNum(kpi?.csat_parity_gap)} hint="human minus self-help (target near 0)" />
      </section>

      <Section title="Channel breakdown" hint="Volume, resolution time, cost saved per channel">
        <DataTable columns={channelCols} rows={channelRows} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Intent breakdown" hint="Deflection and escalation rates by intent category">
        <DataTable columns={intentCols} rows={intentRows} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Top KB articles" hint="By deflections attributed and views">
        <DataTable columns={topKbCols} rows={topKbRows} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="KB needs update" hint="Helpful pct under 50%, stale > 90 days, or marked needs_update">
        <DataTable columns={staleKbCols} rows={staleKbRows} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Daily trend" hint="Last 14 days, IST">
        <DataTable columns={trendCols} rows={trendRows} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Recent escalations" hint="Deflection failures from last 7 days (bot confidence < threshold)">
        <DataTable columns={escCols} rows={escalationRows} rowKey={(_, i) => String(i)} />
      </Section>
    </main>
  );
}

function KpiCard({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <div style={{ border: '1px solid #e5e5e5', borderRadius: '8px', padding: '14px', background: '#fafafa' }}>
      <div style={{ fontSize: '11px', textTransform: 'uppercase', color: '#888', letterSpacing: '0.5px' }}>{label}</div>
      <div style={{ fontSize: '22px', fontWeight: 700, marginTop: '4px' }}>{value}</div>
      {hint ? <div style={{ fontSize: '11px', color: '#888', marginTop: '2px' }}>{hint}</div> : null}
    </div>
  );
}

function Section({ title, hint, children }: { title: string; hint?: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: '28px' }}>
      <div style={{ marginBottom: '10px' }}>
        <h2 style={{ fontSize: '17px', fontWeight: 600 }}>{title}</h2>
        {hint ? <div style={{ fontSize: '12px', color: '#888', marginTop: '2px' }}>{hint}</div> : null}
      </div>
      {children}
    </section>
  );
}
