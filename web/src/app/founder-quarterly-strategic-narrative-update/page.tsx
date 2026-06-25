import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = { total_drafts: number; approved_drafts: number; avg_resonance: number; total_words: number; publish_now_count: number; refine_iterations_avg: number };
type ArcRow = { narrative_arc: string; draft_count: number; avg_resonance: number; total_words: number };
type AudienceRow = { audience: string; draft_count: number; avg_resonance: number; top_channel: string };
type DraftRow = { id: string; quarter: string; narrative_arc: string; headline: string; audience: string; delivery_channel: string; resonance_score: number; refine_iteration: number; signal_action: string; status: string; draft_word_count: number };
type SignalRow = { id: string; headline: string; signal_source: string; resonance_delta: number; refine_suggestion: string; action_recommended: string };
type SignalActionRow = { signal_action: string; draft_count: number; avg_words: number; avg_iteration: number };
type ActionBreakdownRow = { action_recommended: string; signal_count: number; avg_delta: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [ovRes, arcRes, audRes, draftsRes, signalsRes, sigActionsRes, actionBreakRes] = await Promise.all([
    supabase.rpc('founder_qnu_overview_r2709'),
    supabase.rpc('founder_qnu_by_arc_r2709'),
    supabase.rpc('founder_qnu_by_audience_r2709'),
    supabase.rpc('founder_qnu_drafts_r2709'),
    supabase.rpc('founder_qnu_signals_r2709'),
    supabase.rpc('founder_qnu_signal_actions_r2709'),
    supabase.rpc('founder_qnu_action_breakdown_r2709'),
  ]);

  const ov: Overview = (ovRes.data?.[0] ?? { total_drafts: 0, approved_drafts: 0, avg_resonance: 0, total_words: 0, publish_now_count: 0, refine_iterations_avg: 0 }) as Overview;
  const arcRows: ArcRow[] = (arcRes.data ?? []) as ArcRow[];
  const audRows: AudienceRow[] = (audRes.data ?? []) as AudienceRow[];
  const drafts: DraftRow[] = (draftsRes.data ?? []) as DraftRow[];
  const signals: SignalRow[] = (signalsRes.data ?? []) as SignalRow[];
  const sigActions: SignalActionRow[] = (sigActionsRes.data ?? []) as SignalActionRow[];
  const actionBreak: ActionBreakdownRow[] = (actionBreakRes.data ?? []) as ActionBreakdownRow[];

  return (
    <div style={{ padding: '24px', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>Founder Quarterly Strategic Narrative Update</h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>Narrative arc × audience × delivery channel — resonance scoring drives refine & signal action decisions.</p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: '12px', marginBottom: '24px' }}>
        <KpiCard label="Total Drafts" value={String(ov.total_drafts)} />
        <KpiCard label="Approved/Published" value={String(ov.approved_drafts)} />
        <KpiCard label="Avg Resonance" value={`${ov.avg_resonance} / 10`} />
        <KpiCard label="Total Words" value={ov.total_words.toLocaleString()} />
        <KpiCard label="Publish-Now Picks" value={String(ov.publish_now_count)} />
        <KpiCard label="Avg Refine Iter" value={String(ov.refine_iterations_avg)} />
      </div>

      <Section title="Drafts by Narrative Arc">
        <DataTable
          rows={arcRows}
          columns={[
            { key: 'narrative_arc', header: 'Arc', render: (r: ArcRow) => r.narrative_arc },
            { key: 'draft_count', header: 'Drafts', render: (r: ArcRow) => String(r.draft_count) },
            { key: 'avg_resonance', header: 'Avg Resonance', render: (r: ArcRow) => String(r.avg_resonance) },
            { key: 'total_words', header: 'Total Words', render: (r: ArcRow) => r.total_words.toLocaleString() },
          ]}
          emptyMessage="No data"
          rowKey={(r: ArcRow, i: number) => String(r.narrative_arc ?? i)}
        />
      </Section>

      <Section title="Drafts by Audience">
        <DataTable
          rows={audRows}
          columns={[
            { key: 'audience', header: 'Audience', render: (r: AudienceRow) => r.audience },
            { key: 'draft_count', header: 'Drafts', render: (r: AudienceRow) => String(r.draft_count) },
            { key: 'avg_resonance', header: 'Avg Resonance', render: (r: AudienceRow) => String(r.avg_resonance) },
            { key: 'top_channel', header: 'Top Channel', render: (r: AudienceRow) => r.top_channel },
          ]}
          emptyMessage="No data"
          rowKey={(r: AudienceRow, i: number) => String(r.audience ?? i)}
        />
      </Section>

      <Section title="All Drafts">
        <DataTable
          rows={drafts}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r: DraftRow) => r.quarter },
            { key: 'headline', header: 'Headline', render: (r: DraftRow) => r.headline },
            { key: 'narrative_arc', header: 'Arc', render: (r: DraftRow) => r.narrative_arc },
            { key: 'audience', header: 'Audience', render: (r: DraftRow) => r.audience },
            { key: 'delivery_channel', header: 'Channel', render: (r: DraftRow) => r.delivery_channel },
            { key: 'resonance_score', header: 'Resonance', render: (r: DraftRow) => String(r.resonance_score) },
            { key: 'refine_iteration', header: 'Iter', render: (r: DraftRow) => String(r.refine_iteration) },
            { key: 'signal_action', header: 'Signal Action', render: (r: DraftRow) => r.signal_action },
            { key: 'status', header: 'Status', render: (r: DraftRow) => r.status },
            { key: 'draft_word_count', header: 'Words', render: (r: DraftRow) => r.draft_word_count.toLocaleString() },
          ]}
          emptyMessage="No data"
          rowKey={(r: DraftRow, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Resonance Signals (ranked by absolute delta)">
        <DataTable
          rows={signals}
          columns={[
            { key: 'headline', header: 'Draft', render: (r: SignalRow) => r.headline },
            { key: 'signal_source', header: 'Source', render: (r: SignalRow) => r.signal_source },
            { key: 'resonance_delta', header: 'Delta', render: (r: SignalRow) => String(r.resonance_delta) },
            { key: 'refine_suggestion', header: 'Suggestion', render: (r: SignalRow) => r.refine_suggestion },
            { key: 'action_recommended', header: 'Recommended', render: (r: SignalRow) => r.action_recommended },
          ]}
          emptyMessage="No data"
          rowKey={(r: SignalRow, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Signal Action Mix">
        <DataTable
          rows={sigActions}
          columns={[
            { key: 'signal_action', header: 'Action', render: (r: SignalActionRow) => r.signal_action },
            { key: 'draft_count', header: 'Drafts', render: (r: SignalActionRow) => String(r.draft_count) },
            { key: 'avg_words', header: 'Avg Words', render: (r: SignalActionRow) => String(r.avg_words) },
            { key: 'avg_iteration', header: 'Avg Iter', render: (r: SignalActionRow) => String(r.avg_iteration) },
          ]}
          emptyMessage="No data"
          rowKey={(r: SignalActionRow, i: number) => String(r.signal_action ?? i)}
        />
      </Section>

      <Section title="Refine Action Breakdown">
        <DataTable
          rows={actionBreak}
          columns={[
            { key: 'action_recommended', header: 'Refine Action', render: (r: ActionBreakdownRow) => r.action_recommended },
            { key: 'signal_count', header: 'Signals', render: (r: ActionBreakdownRow) => String(r.signal_count) },
            { key: 'avg_delta', header: 'Avg Delta', render: (r: ActionBreakdownRow) => String(r.avg_delta) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ActionBreakdownRow, i: number) => String(r.action_recommended ?? i)}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ background: '#fff', border: '1px solid #e5e5e5', borderRadius: '8px', padding: '14px' }}>
      <div style={{ fontSize: '12px', color: '#666', marginBottom: '6px' }}>{label}</div>
      <div style={{ fontSize: '20px', fontWeight: 700 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: '28px' }}>
      <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '10px' }}>{title}</h2>
      {children}
    </section>
  );
}