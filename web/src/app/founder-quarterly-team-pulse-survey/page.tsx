import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderQuarterlyTeamPulseSurveyPage() {
  const supabase = await getSupabaseServerClient();

  const [
    surveysRes,
    themesRes,
    pulseTrendRes,
    themeSentimentRes,
    topConcernsRes,
    actionFunnelRes,
    responseRateRes,
  ] = await Promise.all([
    supabase.rpc('list_surveys_r2545'),
    supabase.rpc('list_response_themes_r2545'),
    supabase.rpc('quarterly_pulse_trend_r2545'),
    supabase.rpc('theme_sentiment_summary_r2545'),
    supabase.rpc('top_concerns_focus_r2545'),
    supabase.rpc('action_status_funnel_r2545'),
    supabase.rpc('response_rate_trend_r2545'),
  ]);

  const surveys = (surveysRes.data ?? []) as any[];
  const themes = (themesRes.data ?? []) as any[];
  const pulseTrend = (pulseTrendRes.data ?? []) as any[];
  const themeSentiment = (themeSentimentRes.data ?? []) as any[];
  const topConcerns = (topConcernsRes.data ?? []) as any[];
  const actionFunnel = (actionFunnelRes.data ?? []) as any[];
  const responseRate = (responseRateRes.data ?? []) as any[];

  const surveyCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'team_size', header: 'Team Size', render: (r: any) => r.team_size },
    { key: 'response_count', header: 'Responses', render: (r: any) => r.response_count },
    { key: 'response_rate_pct', header: 'Rate %', render: (r: any) => `${r.response_rate_pct}%` },
    { key: 'overall_pulse_score', header: 'Pulse', render: (r: any) => `${r.overall_pulse_score}/100` },
    { key: 'top_concern_md', header: 'Top Concern', render: (r: any) => r.top_concern_md ?? '-' },
    { key: 'action_plan_md', header: 'Action Plan', render: (r: any) => r.action_plan_md ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const themeCols: Column<any>[] = [
    { key: 'survey_id', header: 'Survey', render: (r: any) => String(r.survey_id).slice(0, 8) },
    { key: 'theme_kind', header: 'Theme', render: (r: any) => r.theme_kind },
    { key: 'mentions_count', header: 'Mentions', render: (r: any) => r.mentions_count },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => r.sentiment },
    { key: 'founder_response_md', header: 'Founder Response', render: (r: any) => r.founder_response_md ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const pulseCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'overall_pulse_score', header: 'Pulse Score', render: (r: any) => `${r.overall_pulse_score}/100` },
    { key: 'response_rate_pct', header: 'Response %', render: (r: any) => `${r.response_rate_pct}%` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const sentimentCols: Column<any>[] = [
    { key: 'theme_kind', header: 'Theme', render: (r: any) => r.theme_kind },
    { key: 'total_mentions', header: 'Total', render: (r: any) => r.total_mentions },
    { key: 'negative_mentions', header: 'Negative', render: (r: any) => r.negative_mentions },
    { key: 'positive_mentions', header: 'Positive', render: (r: any) => r.positive_mentions },
    { key: 'mixed_mentions', header: 'Mixed', render: (r: any) => r.mixed_mentions },
    { key: 'neutral_mentions', header: 'Neutral', render: (r: any) => r.neutral_mentions },
  ];

  const concernCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'theme_kind', header: 'Theme', render: (r: any) => r.theme_kind },
    { key: 'mentions_count', header: 'Mentions', render: (r: any) => r.mentions_count },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => r.sentiment },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'founder_response_md', header: 'Response', render: (r: any) => r.founder_response_md ?? '-' },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'theme_count', header: 'Themes', render: (r: any) => r.theme_count },
    { key: 'total_mentions', header: 'Mentions', render: (r: any) => r.total_mentions },
  ];

  const rateCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'team_size', header: 'Team Size', render: (r: any) => r.team_size },
    { key: 'response_count', header: 'Responses', render: (r: any) => r.response_count },
    { key: 'response_rate_pct', header: 'Rate %', render: (r: any) => `${r.response_rate_pct}%` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: '1280px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.875rem', fontWeight: 700, marginBottom: '0.5rem' }}>
        Founder Quarterly Team Pulse Survey
      </h1>
      <p style={{ color: '#666', marginBottom: '2rem' }}>
        Quarter &gt; team size &gt; pulse score &gt; responses &gt; top concern &gt; action plan. Founder-only.
      </p>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Surveys</h2>
        <DataTable
          rows={surveys}
          columns={surveyCols}
          emptyMessage="No surveys yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Response Themes</h2>
        <DataTable
          rows={themes}
          columns={themeCols}
          emptyMessage="No themes yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Quarterly Pulse Trend</h2>
        <DataTable
          rows={pulseTrend}
          columns={pulseCols}
          emptyMessage="No trend"
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Theme Sentiment Summary</h2>
        <DataTable
          rows={themeSentiment}
          columns={sentimentCols}
          emptyMessage="No sentiment data"
          rowKey={(r: any, i: number) => String(r.theme_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Top Concerns Focus</h2>
        <DataTable
          rows={topConcerns}
          columns={concernCols}
          emptyMessage="No concerns"
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Action Status Funnel</h2>
        <DataTable
          rows={actionFunnel}
          columns={funnelCols}
          emptyMessage="No actions"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Response Rate Trend</h2>
        <DataTable
          rows={responseRate}
          columns={rateCols}
          emptyMessage="No rate data"
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>
    </main>
  );
}
