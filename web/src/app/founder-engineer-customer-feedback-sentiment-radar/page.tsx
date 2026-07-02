import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SignalRow = {
  id: string;
  engineer_email: string | null;
  engineer_name: string | null;
  collected_at: string;
  sentiment_label: string;
  sentiment_score: number | null;
  primary_theme: string;
  csat_score: number | null;
  nps_score: number | null;
  feedback_preview: string | null;
  contains_complaint: boolean;
  contains_praise: boolean;
  has_action: boolean;
};

type RadarRow = {
  engineer_id: string;
  engineer_email: string | null;
  engineer_name: string | null;
  total_feedback: number;
  positive_pct: number | null;
  negative_pct: number | null;
  neutral_pct: number | null;
  avg_sentiment: number | null;
  avg_csat: number | null;
  avg_nps: number | null;
  complaint_count: number;
  praise_count: number;
  open_action_count: number;
};

type ThemeRow = {
  theme: string;
  total_count: number;
  negative_count: number;
  positive_count: number;
  avg_sentiment: number | null;
  share_pct: number | null;
};

type ActionRow = {
  id: string;
  signal_id: string;
  engineer_email: string | null;
  engineer_name: string | null;
  action_type: string;
  action_priority: string;
  action_status: string;
  assigned_to_email: string | null;
  due_at: string | null;
  age_days: number;
  feedback_preview: string | null;
  sentiment_label: string;
  primary_theme: string;
};

type EmotionRow = {
  emotion_tag: string;
  occurrences: number;
  negative_share_pct: number | null;
};

type KpiRow = {
  total_signals: number;
  analyzed_signals: number;
  pct_negative: number | null;
  pct_positive: number | null;
  avg_sentiment: number | null;
  avg_csat: number | null;
  avg_nps: number | null;
  complaint_count: number;
  praise_count: number;
  competitor_mentions: number;
  pii_flagged: number;
  open_actions: number;
  urgent_open_actions: number;
};

function fmt(n: number | null | undefined, suffix = '') {
  if (n === null || n === undefined) return '—';
  return `${n}${suffix}`;
}

function sentimentBadge(label: string) {
  const map: Record<string, { bg: string; fg: string }> = {
    positive: { bg: '#dcfce7', fg: '#166534' },
    negative: { bg: '#fee2e2', fg: '#991b1b' },
    neutral: { bg: '#e5e7eb', fg: '#374151' },
    mixed: { bg: '#fef3c7', fg: '#92400e' },
  };
  const c = map[label] ?? map.neutral;
  return (
    <span style={{ background: c.bg, color: c.fg, padding: '2px 8px', borderRadius: 12, fontSize: 12, fontWeight: 600 }}>
      {label}
    </span>
  );
}

function priorityBadge(p: string) {
  const map: Record<string, string> = {
    urgent: '#dc2626',
    high: '#ea580c',
    medium: '#ca8a04',
    low: '#6b7280',
  };
  return (
    <span style={{ background: map[p] ?? '#6b7280', color: 'white', padding: '2px 8px', borderRadius: 12, fontSize: 11, fontWeight: 600, textTransform: 'uppercase' }}>
      {p}
    </span>
  );
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, signalsRes, radarRes, themesRes, actionsRes, emotionsRes] = await Promise.all([
    supabase.rpc('r2342_summary_kpis', { p_days: 30 }),
    supabase.rpc('r2342_list_recent_signals', { p_limit: 100 }),
    supabase.rpc('r2342_sentiment_radar_by_engineer', { p_days: 30 }),
    supabase.rpc('r2342_theme_cluster_breakdown', { p_days: 30 }),
    supabase.rpc('r2342_open_action_queue'),
    supabase.rpc('r2342_emotion_tag_heatmap', { p_days: 30 }),
  ]);

  const kpis: KpiRow | null = (kpisRes.data?.[0] as KpiRow) ?? null;
  const signals: SignalRow[] = (signalsRes.data as SignalRow[]) ?? [];
  const radar: RadarRow[] = (radarRes.data as RadarRow[]) ?? [];
  const themes: ThemeRow[] = (themesRes.data as ThemeRow[]) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];
  const emotions: EmotionRow[] = (emotionsRes.data as EmotionRow[]) ?? [];

  const signalCols: Column<SignalRow>[] = [
    { key: 'collected_at', header: 'When', render: (r: SignalRow) => new Date(r.collected_at).toLocaleString() },
    { key: 'engineer', header: 'Engineer', render: (r: SignalRow) => r.engineer_name || r.engineer_email || '—' },
    { key: 'sentiment', header: 'Sentiment', render: (r: SignalRow) => (
      <span>{sentimentBadge(r.sentiment_label)} <span style={{ marginLeft: 6, color: '#6b7280', fontSize: 12 }}>{fmt(r.sentiment_score)}</span></span>
    ) },
    { key: 'theme', header: 'Theme', render: (r: SignalRow) => r.primary_theme },
    { key: 'csat', header: 'CSAT', render: (r: SignalRow) => fmt(r.csat_score) },
    { key: 'nps', header: 'NPS', render: (r: SignalRow) => fmt(r.nps_score) },
    { key: 'flags', header: 'Flags', render: (r: SignalRow) => (
      <span style={{ fontSize: 11 }}>
        {r.contains_complaint && <span style={{ color: '#991b1b', marginRight: 6 }}>complaint</span>}
        {r.contains_praise && <span style={{ color: '#166534', marginRight: 6 }}>praise</span>}
        {r.has_action && <span style={{ color: '#1e40af' }}>action</span>}
      </span>
    ) },
    { key: 'preview', header: 'Preview', render: (r: SignalRow) => (
      <span style={{ fontSize: 12, color: '#374151' }}>{r.feedback_preview || '—'}</span>
    ) },
  ];

  const radarCols: Column<RadarRow>[] = [
    { key: 'engineer', header: 'Engineer', render: (r: RadarRow) => r.engineer_name || r.engineer_email || '—' },
    { key: 'total', header: 'Total', render: (r: RadarRow) => r.total_feedback },
    { key: 'pos', header: 'Pos %', render: (r: RadarRow) => fmt(r.positive_pct, '%') },
    { key: 'neg', header: 'Neg %', render: (r: RadarRow) => fmt(r.negative_pct, '%') },
    { key: 'avg', header: 'Avg Sentiment', render: (r: RadarRow) => fmt(r.avg_sentiment) },
    { key: 'csat', header: 'Avg CSAT', render: (r: RadarRow) => fmt(r.avg_csat) },
    { key: 'nps', header: 'Avg NPS', render: (r: RadarRow) => fmt(r.avg_nps) },
    { key: 'complaints', header: 'Complaints', render: (r: RadarRow) => r.complaint_count },
    { key: 'praise', header: 'Praise', render: (r: RadarRow) => r.praise_count },
    { key: 'open_actions', header: 'Open Actions', render: (r: RadarRow) => r.open_action_count },
  ];

  const themeCols: Column<ThemeRow>[] = [
    { key: 'theme', header: 'Theme', render: (r: ThemeRow) => r.theme },
    { key: 'count', header: 'Count', render: (r: ThemeRow) => r.total_count },
    { key: 'neg', header: 'Negative', render: (r: ThemeRow) => r.negative_count },
    { key: 'pos', header: 'Positive', render: (r: ThemeRow) => r.positive_count },
    { key: 'avg', header: 'Avg Sentiment', render: (r: ThemeRow) => fmt(r.avg_sentiment) },
    { key: 'share', header: 'Share %', render: (r: ThemeRow) => fmt(r.share_pct, '%') },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'priority', header: 'Priority', render: (r: ActionRow) => priorityBadge(r.action_priority) },
    { key: 'engineer', header: 'Engineer', render: (r: ActionRow) => r.engineer_name || r.engineer_email || '—' },
    { key: 'type', header: 'Action', render: (r: ActionRow) => r.action_type },
    { key: 'status', header: 'Status', render: (r: ActionRow) => r.action_status },
    { key: 'assigned', header: 'Assigned To', render: (r: ActionRow) => r.assigned_to_email || '—' },
    { key: 'due', header: 'Due', render: (r: ActionRow) => r.due_at ? new Date(r.due_at).toLocaleDateString() : '—' },
    { key: 'age', header: 'Age (days)', render: (r: ActionRow) => r.age_days },
    { key: 'sentiment', header: 'Signal', render: (r: ActionRow) => (
      <span>{sentimentBadge(r.sentiment_label)} <span style={{ marginLeft: 6, color: '#6b7280' }}>{r.primary_theme}</span></span>
    ) },
    { key: 'preview', header: 'Preview', render: (r: ActionRow) => (
      <span style={{ fontSize: 12, color: '#374151' }}>{r.feedback_preview || '—'}</span>
    ) },
  ];

  const emotionCols: Column<EmotionRow>[] = [
    { key: 'tag', header: 'Emotion', render: (r: EmotionRow) => r.emotion_tag },
    { key: 'occ', header: 'Occurrences', render: (r: EmotionRow) => r.occurrences },
    { key: 'neg_share', header: 'Negative Share %', render: (r: EmotionRow) => fmt(r.negative_share_pct, '%') },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, -apple-system, sans-serif', maxWidth: 1400, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 26, fontWeight: 700, margin: 0 }}>Engineer Customer Feedback & Sentiment Radar</h1>
        <p style={{ color: '#6b7280', marginTop: 4 }}>
          Free-text CSAT &amp; NPS sentiment, theme clusters &amp; coaching action queue =&gt; turn raw feedback into engineer-level signal.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12, marginBottom: 28 }}>
        {[
          { label: 'Total signals (30d)', value: kpis?.total_signals ?? 0 },
          { label: 'Analyzed', value: kpis?.analyzed_signals ?? 0 },
          { label: 'Negative %', value: `${kpis?.pct_negative ?? 0}%`, alert: (kpis?.pct_negative ?? 0) > 20 },
          { label: 'Positive %', value: `${kpis?.pct_positive ?? 0}%` },
          { label: 'Avg sentiment', value: kpis?.avg_sentiment ?? '—' },
          { label: 'Avg CSAT', value: kpis?.avg_csat ?? '—' },
          { label: 'Avg NPS', value: kpis?.avg_nps ?? '—' },
          { label: 'Complaints', value: kpis?.complaint_count ?? 0, alert: (kpis?.complaint_count ?? 0) > 0 },
          { label: 'Praise', value: kpis?.praise_count ?? 0 },
          { label: 'Competitor mentions', value: kpis?.competitor_mentions ?? 0, alert: (kpis?.competitor_mentions ?? 0) > 0 },
          { label: 'PII flagged', value: kpis?.pii_flagged ?? 0 },
          { label: 'Open actions', value: kpis?.open_actions ?? 0 },
          { label: 'Urgent open', value: kpis?.urgent_open_actions ?? 0, alert: (kpis?.urgent_open_actions ?? 0) > 0 },
        ].map((k, i) => (
          <div key={i} style={{
            background: k.alert ? '#fef2f2' : '#f9fafb',
            border: k.alert ? '1px solid #fecaca' : '1px solid #e5e7eb',
            borderRadius: 8,
            padding: 12,
          }}>
            <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>{k.label}</div>
            <div style={{ fontSize: 22, fontWeight: 700, color: k.alert ? '#991b1b' : '#111827', marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Open action queue ({actions.length})</h2>
        <p style={{ color: '#6b7280', fontSize: 13, marginTop: 0, marginBottom: 10 }}>
          Coaching, retraining &amp; escalation actions triggered by negative or flagged feedback. Sorted by priority =&gt; due date.
        </p>
        <DataTable rows={actions} emptyMessage="No open actions — feedback queue is clear." rowKey={(r: ActionRow) => r.id} columns={actionCols} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Engineer sentiment radar (30d)</h2>
        <p style={{ color: '#6b7280', fontSize: 13, marginTop: 0, marginBottom: 10 }}>
          Lowest avg sentiment first =&gt; surfaces who needs coaching attention.
        </p>
        <DataTable rows={radar} emptyMessage="No engineer feedback in the last 30 days." rowKey={(r: RadarRow) => r.engineer_id} columns={radarCols} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Theme cluster breakdown</h2>
        <p style={{ color: '#6b7280', fontSize: 13, marginTop: 0, marginBottom: 10 }}>
          Where customers are spending their words =&gt; which themes drive negative volume.
        </p>
        <DataTable rows={themes} emptyMessage="No themed feedback in window." rowKey={(r: ThemeRow) => r.theme} columns={themeCols} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Emotion-tag heatmap</h2>
        <p style={{ color: '#6b7280', fontSize: 13, marginTop: 0, marginBottom: 10 }}>
          Top emotion tags with negative share &gt;= concerning levels flagged for follow-up.
        </p>
        <DataTable rows={emotions} emptyMessage="No emotion tags captured." rowKey={(r: EmotionRow) => r.emotion_tag} columns={emotionCols} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Recent feedback signals ({signals.length})</h2>
        <DataTable rows={signals} emptyMessage="No feedback collected yet." rowKey={(r: SignalRow) => r.id} columns={signalCols} />
      </section>
    </div>
  );
}
