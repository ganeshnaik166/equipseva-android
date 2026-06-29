import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type PostRow = { post_slug: string; quarter: string; month_label: string; pillar: string; voice_tone: string; headline: string; impressions: number; reactions: number; on_brand_score: number; status: string };
type MonthRow = { month_label: string; posts_count: number; total_impressions: number; total_reactions: number; avg_brand_score: number; posted_count: number };
type PillarRow = { pillar: string; post_count: number; posted_count: number; avg_brand_score: number; total_impressions: number };
type ToneRow = { voice_tone: string; post_count: number; avg_brand_score: number; avg_impressions: number };
type AuditRow = { audit_slug: string; audit_month: string; voice_drift_dimension: string; severity: string; posts_reviewed: number; off_brand_count: number; drift_summary: string; audit_status: string };
type DriftRow = { voice_drift_dimension: string; audit_count: number; open_count: number; total_off_brand: number; worst_severity: string };
type QuarterRow = { quarter: string; fiscal_year: number; posts_count: number; posted_count: number; avg_brand_score: number; total_impressions: number; off_brand_total: number };
type TopRow = { post_slug: string; headline: string; pillar: string; voice_tone: string; impressions: number; reactions: number; reposts: number; engagement_rate: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [posts, months, pillars, tones, audits, drifts, quarters, top] = await Promise.all([
    supabase.rpc('fn_r2941_posts_overview'),
    supabase.rpc('fn_r2941_monthly_engagement_rollup'),
    supabase.rpc('fn_r2941_pillar_mix'),
    supabase.rpc('fn_r2941_voice_tone_distribution'),
    supabase.rpc('fn_r2941_audit_queue'),
    supabase.rpc('fn_r2941_drift_by_dimension'),
    supabase.rpc('fn_r2941_quarterly_brand_health'),
    supabase.rpc('fn_r2941_top_posts_by_engagement'),
  ]);

  const postRows = (posts.data ?? []) as PostRow[];
  const monthRows = (months.data ?? []) as MonthRow[];
  const pillarRows = (pillars.data ?? []) as PillarRow[];
  const toneRows = (tones.data ?? []) as ToneRow[];
  const auditRows = (audits.data ?? []) as AuditRow[];
  const driftRows = (drifts.data ?? []) as DriftRow[];
  const quarterRows = (quarters.data ?? []) as QuarterRow[];
  const topRows = (top.data ?? []) as TopRow[];

  const postCols: Column<PostRow>[] = [
    { key: 'month_label', header: 'Month', render: (r) => r.month_label },
    { key: 'pillar', header: 'Pillar', render: (r) => r.pillar },
    { key: 'voice_tone', header: 'Tone', render: (r) => r.voice_tone },
    { key: 'headline', header: 'Headline', render: (r) => r.headline },
    { key: 'impressions', header: 'Impressions', render: (r) => r.impressions.toLocaleString() },
    { key: 'reactions', header: 'Reactions', render: (r) => r.reactions.toLocaleString() },
    { key: 'on_brand_score', header: 'Brand Score', render: (r) => r.on_brand_score.toFixed(2) },
    { key: 'status', header: 'Status', render: (r) => r.status },
  ];

  const monthCols: Column<MonthRow>[] = [
    { key: 'month_label', header: 'Month', render: (r) => r.month_label },
    { key: 'posts_count', header: 'Posts', render: (r) => r.posts_count },
    { key: 'posted_count', header: 'Posted', render: (r) => r.posted_count },
    { key: 'total_impressions', header: 'Impressions', render: (r) => Number(r.total_impressions).toLocaleString() },
    { key: 'total_reactions', header: 'Reactions', render: (r) => Number(r.total_reactions).toLocaleString() },
    { key: 'avg_brand_score', header: 'Avg Brand Score', render: (r) => Number(r.avg_brand_score).toFixed(2) },
  ];

  const pillarCols: Column<PillarRow>[] = [
    { key: 'pillar', header: 'Pillar', render: (r) => r.pillar },
    { key: 'post_count', header: 'Posts', render: (r) => r.post_count },
    { key: 'posted_count', header: 'Posted', render: (r) => r.posted_count },
    { key: 'avg_brand_score', header: 'Avg Score', render: (r) => Number(r.avg_brand_score).toFixed(2) },
    { key: 'total_impressions', header: 'Impressions', render: (r) => Number(r.total_impressions).toLocaleString() },
  ];

  const toneCols: Column<ToneRow>[] = [
    { key: 'voice_tone', header: 'Voice Tone', render: (r) => r.voice_tone },
    { key: 'post_count', header: 'Posts', render: (r) => r.post_count },
    { key: 'avg_brand_score', header: 'Avg Score', render: (r) => Number(r.avg_brand_score).toFixed(2) },
    { key: 'avg_impressions', header: 'Avg Impressions', render: (r) => Number(r.avg_impressions).toLocaleString() },
  ];

  const auditCols: Column<AuditRow>[] = [
    { key: 'audit_month', header: 'Month', render: (r) => r.audit_month },
    { key: 'voice_drift_dimension', header: 'Dimension', render: (r) => r.voice_drift_dimension },
    { key: 'severity', header: 'Severity', render: (r) => r.severity },
    { key: 'posts_reviewed', header: 'Reviewed', render: (r) => r.posts_reviewed },
    { key: 'off_brand_count', header: 'Off-brand', render: (r) => r.off_brand_count },
    { key: 'drift_summary', header: 'Summary', render: (r) => r.drift_summary },
    { key: 'audit_status', header: 'Status', render: (r) => r.audit_status },
  ];

  const driftCols: Column<DriftRow>[] = [
    { key: 'voice_drift_dimension', header: 'Dimension', render: (r) => r.voice_drift_dimension },
    { key: 'audit_count', header: 'Audits', render: (r) => r.audit_count },
    { key: 'open_count', header: 'Open', render: (r) => r.open_count },
    { key: 'total_off_brand', header: 'Off-brand Total', render: (r) => Number(r.total_off_brand) },
    { key: 'worst_severity', header: 'Worst Severity', render: (r) => r.worst_severity },
  ];

  const quarterCols: Column<QuarterRow>[] = [
    { key: 'fiscal_year', header: 'FY', render: (r) => r.fiscal_year },
    { key: 'quarter', header: 'Quarter', render: (r) => r.quarter },
    { key: 'posts_count', header: 'Posts', render: (r) => r.posts_count },
    { key: 'posted_count', header: 'Posted', render: (r) => r.posted_count },
    { key: 'avg_brand_score', header: 'Avg Brand', render: (r) => Number(r.avg_brand_score).toFixed(2) },
    { key: 'total_impressions', header: 'Impressions', render: (r) => Number(r.total_impressions).toLocaleString() },
    { key: 'off_brand_total', header: 'Off-brand', render: (r) => Number(r.off_brand_total) },
  ];

  const topCols: Column<TopRow>[] = [
    { key: 'headline', header: 'Headline', render: (r) => r.headline },
    { key: 'pillar', header: 'Pillar', render: (r) => r.pillar },
    { key: 'voice_tone', header: 'Tone', render: (r) => r.voice_tone },
    { key: 'impressions', header: 'Impressions', render: (r) => r.impressions.toLocaleString() },
    { key: 'reactions', header: 'Reactions', render: (r) => r.reactions.toLocaleString() },
    { key: 'reposts', header: 'Reposts', render: (r) => r.reposts.toLocaleString() },
    { key: 'engagement_rate', header: 'Engagement %', render: (r) => Number(r.engagement_rate).toFixed(2) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Monthly &amp; Quarterly LinkedIn Brand Voice Posting Audit</h1>
        <p className="text-sm text-gray-600">Founder voice consistency &gt;= 9.0/10 target. Pillar mix discipline. Drift caught monthly, rolled up quarterly.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly Brand Health</h2>
        <DataTable rows={quarterRows} columns={quarterCols} emptyMessage="No quarterly data" rowKey={(r, i) => String((r as QuarterRow).quarter + (r as QuarterRow).fiscal_year ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Engagement Rollup</h2>
        <DataTable rows={monthRows} columns={monthCols} emptyMessage="No months" rowKey={(r, i) => String((r as MonthRow).month_label ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pillar Mix</h2>
        <DataTable rows={pillarRows} columns={pillarCols} emptyMessage="No pillars" rowKey={(r, i) => String((r as PillarRow).pillar ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Voice Tone Distribution</h2>
        <DataTable rows={toneRows} columns={toneCols} emptyMessage="No tones" rowKey={(r, i) => String((r as ToneRow).voice_tone ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Posts by Engagement</h2>
        <DataTable rows={topRows} columns={topCols} emptyMessage="No posted content" rowKey={(r, i) => String((r as TopRow).post_slug ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Audit Queue (severity-ranked)</h2>
        <DataTable rows={auditRows} columns={auditCols} emptyMessage="No audits" rowKey={(r, i) => String((r as AuditRow).audit_slug ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Drift by Dimension</h2>
        <DataTable rows={driftRows} columns={driftCols} emptyMessage="No drift" rowKey={(r, i) => String((r as DriftRow).voice_drift_dimension ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Posts (most recent first)</h2>
        <DataTable rows={postRows} columns={postCols} emptyMessage="No posts" rowKey={(r, i) => String((r as PostRow).post_slug ?? i)} />
      </section>
    </main>
  );
}
