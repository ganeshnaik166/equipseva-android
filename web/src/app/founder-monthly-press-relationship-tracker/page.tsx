import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_reporters: number;
  advocates_strong: number;
  engaged_warm: number;
  cold: number;
  total_coverage_ytd: number;
  total_reach_k: number;
  p0_priorities: number;
  june_outreach_count: number;
  june_published_count: number;
};

type RosterRow = {
  reporter_name: string;
  outlet: string;
  beat: string;
  outlet_tier: string;
  relationship_strength: string;
  founder_priority: string;
  coverage_count_ytd: number;
  reach_estimate_k: number;
  last_touch_date: string;
  next_deepen_action: string;
};

type OutreachRow = {
  outreach_month: string;
  reporter_name: string;
  outlet: string;
  outreach_type: string;
  ask_category: string;
  ask_summary: string;
  response_status: string;
  coverage_published: boolean;
  founder_satisfaction: number | null;
};

type BeatRow = {
  beat: string;
  reporter_count: number;
  coverage_ytd: number;
  reach_k: number;
  avg_strength_score: number;
};

type TierRow = {
  outlet_tier: string;
  reporter_count: number;
  coverage_ytd: number;
  reach_k: number;
  published_june: number;
};

type StaleRow = {
  reporter_name: string;
  outlet: string;
  founder_priority: string;
  relationship_strength: string;
  last_touch_date: string;
  days_since_touch: number;
  next_deepen_action: string;
};

type DeepenRow = {
  reporter_name: string;
  outlet: string;
  founder_priority: string;
  relationship_strength: string;
  next_deepen_action: string;
  reach_estimate_k: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, rosterRes, logRes, beatRes, tierRes, staleRes, deepenRes] = await Promise.all([
    supabase.rpc('fn_press_relationship_kpis_r2773'),
    supabase.rpc('fn_press_roster_r2773'),
    supabase.rpc('fn_press_outreach_log_r2773'),
    supabase.rpc('fn_press_beat_rollup_r2773'),
    supabase.rpc('fn_press_tier_rollup_r2773'),
    supabase.rpc('fn_press_stale_relationships_r2773'),
    supabase.rpc('fn_press_deepen_queue_r2773'),
  ]);

  const kpis: Kpis = (kpisRes.data?.[0] ?? {
    total_reporters: 0,
    advocates_strong: 0,
    engaged_warm: 0,
    cold: 0,
    total_coverage_ytd: 0,
    total_reach_k: 0,
    p0_priorities: 0,
    june_outreach_count: 0,
    june_published_count: 0,
  }) as Kpis;

  const roster: RosterRow[] = (rosterRes.data ?? []) as RosterRow[];
  const log: OutreachRow[] = (logRes.data ?? []) as OutreachRow[];
  const beats: BeatRow[] = (beatRes.data ?? []) as BeatRow[];
  const tiers: TierRow[] = (tierRes.data ?? []) as TierRow[];
  const stale: StaleRow[] = (staleRes.data ?? []) as StaleRow[];
  const deepen: DeepenRow[] = (deepenRes.data ?? []) as DeepenRow[];

  const kpiCards = [
    { label: 'Reporters tracked', value: kpis.total_reporters },
    { label: 'Advocates + strong', value: kpis.advocates_strong },
    { label: 'Engaged + warm', value: kpis.engaged_warm },
    { label: 'Cold', value: kpis.cold },
    { label: 'Coverage YTD', value: kpis.total_coverage_ytd },
    { label: 'Total reach (k)', value: kpis.total_reach_k },
    { label: 'P0 priority', value: kpis.p0_priorities },
    { label: 'June outreach', value: kpis.june_outreach_count },
    { label: 'June published', value: kpis.june_published_count },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1280px', margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700, margin: 0 }}>
          Founder Monthly Press Relationship Tracker
        </h1>
        <p style={{ color: '#555', marginTop: '6px' }}>
          Reporter x outlet x beat x ask x coverage x strength x deepen action. Stale threshold &gt;= 30 days since last touch.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: '12px', marginBottom: '32px' }}>
        {kpiCards.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e5e5', borderRadius: '8px', padding: '14px', background: '#fafafa' }}>
            <div style={{ fontSize: '12px', color: '#666', textTransform: 'uppercase', letterSpacing: '0.5px' }}>{k.label}</div>
            <div style={{ fontSize: '24px', fontWeight: 700, marginTop: '4px' }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Reporter roster (priority + strength sorted)</h2>
        <DataTable
          rows={roster}
          columns={[
            { key: 'reporter_name', header: 'Reporter', render: (r: RosterRow) => r.reporter_name },
            { key: 'outlet', header: 'Outlet', render: (r: RosterRow) => r.outlet },
            { key: 'beat', header: 'Beat', render: (r: RosterRow) => r.beat },
            { key: 'outlet_tier', header: 'Tier', render: (r: RosterRow) => r.outlet_tier },
            { key: 'relationship_strength', header: 'Strength', render: (r: RosterRow) => r.relationship_strength },
            { key: 'founder_priority', header: 'Priority', render: (r: RosterRow) => r.founder_priority },
            { key: 'coverage_count_ytd', header: 'YTD coverage', render: (r: RosterRow) => String(r.coverage_count_ytd) },
            { key: 'reach_estimate_k', header: 'Reach (k)', render: (r: RosterRow) => String(r.reach_estimate_k) },
            { key: 'last_touch_date', header: 'Last touch', render: (r: RosterRow) => r.last_touch_date },
            { key: 'next_deepen_action', header: 'Next deepen action', render: (r: RosterRow) => r.next_deepen_action },
          ]}
          emptyMessage="No data"
          rowKey={(r: RosterRow, i: number) => String(r.reporter_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Deepen queue (P0 + P1)</h2>
        <DataTable
          rows={deepen}
          columns={[
            { key: 'founder_priority', header: 'Priority', render: (r: DeepenRow) => r.founder_priority },
            { key: 'reporter_name', header: 'Reporter', render: (r: DeepenRow) => r.reporter_name },
            { key: 'outlet', header: 'Outlet', render: (r: DeepenRow) => r.outlet },
            { key: 'relationship_strength', header: 'Strength', render: (r: DeepenRow) => r.relationship_strength },
            { key: 'reach_estimate_k', header: 'Reach (k)', render: (r: DeepenRow) => String(r.reach_estimate_k) },
            { key: 'next_deepen_action', header: 'Deepen action', render: (r: DeepenRow) => r.next_deepen_action },
          ]}
          emptyMessage="No data"
          rowKey={(r: DeepenRow, i: number) => String(r.reporter_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Stale relationships (no touch in 30+ days)</h2>
        <DataTable
          rows={stale}
          columns={[
            { key: 'reporter_name', header: 'Reporter', render: (r: StaleRow) => r.reporter_name },
            { key: 'outlet', header: 'Outlet', render: (r: StaleRow) => r.outlet },
            { key: 'founder_priority', header: 'Priority', render: (r: StaleRow) => r.founder_priority },
            { key: 'relationship_strength', header: 'Strength', render: (r: StaleRow) => r.relationship_strength },
            { key: 'last_touch_date', header: 'Last touch', render: (r: StaleRow) => r.last_touch_date },
            { key: 'days_since_touch', header: 'Days idle', render: (r: StaleRow) => String(r.days_since_touch) },
            { key: 'next_deepen_action', header: 'Re-engage plan', render: (r: StaleRow) => r.next_deepen_action },
          ]}
          emptyMessage="No data"
          rowKey={(r: StaleRow, i: number) => String(r.reporter_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>June outreach log</h2>
        <DataTable
          rows={log}
          columns={[
            { key: 'outreach_month', header: 'Month', render: (r: OutreachRow) => r.outreach_month },
            { key: 'reporter_name', header: 'Reporter', render: (r: OutreachRow) => r.reporter_name },
            { key: 'outlet', header: 'Outlet', render: (r: OutreachRow) => r.outlet },
            { key: 'outreach_type', header: 'Type', render: (r: OutreachRow) => r.outreach_type },
            { key: 'ask_category', header: 'Ask', render: (r: OutreachRow) => r.ask_category },
            { key: 'ask_summary', header: 'Summary', render: (r: OutreachRow) => r.ask_summary },
            { key: 'response_status', header: 'Status', render: (r: OutreachRow) => r.response_status },
            { key: 'coverage_published', header: 'Published', render: (r: OutreachRow) => (r.coverage_published ? 'yes' : 'no') },
            { key: 'founder_satisfaction', header: 'Founder rating', render: (r: OutreachRow) => (r.founder_satisfaction === null ? '-' : String(r.founder_satisfaction)) },
          ]}
          emptyMessage="No data"
          rowKey={(r: OutreachRow, i: number) => String(i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Rollup by beat</h2>
        <DataTable
          rows={beats}
          columns={[
            { key: 'beat', header: 'Beat', render: (r: BeatRow) => r.beat },
            { key: 'reporter_count', header: 'Reporters', render: (r: BeatRow) => String(r.reporter_count) },
            { key: 'coverage_ytd', header: 'Coverage YTD', render: (r: BeatRow) => String(r.coverage_ytd) },
            { key: 'reach_k', header: 'Reach (k)', render: (r: BeatRow) => String(r.reach_k) },
            { key: 'avg_strength_score', header: 'Avg strength (1-5)', render: (r: BeatRow) => String(r.avg_strength_score) },
          ]}
          emptyMessage="No data"
          rowKey={(r: BeatRow, i: number) => String(r.beat ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Rollup by outlet tier</h2>
        <DataTable
          rows={tiers}
          columns={[
            { key: 'outlet_tier', header: 'Tier', render: (r: TierRow) => r.outlet_tier },
            { key: 'reporter_count', header: 'Reporters', render: (r: TierRow) => String(r.reporter_count) },
            { key: 'coverage_ytd', header: 'Coverage YTD', render: (r: TierRow) => String(r.coverage_ytd) },
            { key: 'reach_k', header: 'Reach (k)', render: (r: TierRow) => String(r.reach_k) },
            { key: 'published_june', header: 'Published in June', render: (r: TierRow) => String(r.published_june) },
          ]}
          emptyMessage="No data"
          rowKey={(r: TierRow, i: number) => String(r.outlet_tier ?? i)}
        />
      </section>
    </div>
  );
}
