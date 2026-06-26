import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  quarter: string;
  narrative_theme: string;
  tagline: string;
  verdict: string;
  differentiation_score: number;
  resonance_score: number;
  market_clarity_score: number;
  recorded_at: string;
};

type Kpi = {
  total_quarters: number;
  crisp_count: number;
  muddled_count: number;
  avg_differentiation: number;
  avg_resonance: number;
  avg_market_clarity: number;
};

type Peer = {
  quarter: string;
  narrative_theme: string;
  peer_benchmark: string;
  differentiation_score: number;
  verdict: string;
};

type ChannelRow = {
  channel: string;
  signal_count: number;
  avg_strength: number;
  positive_count: number;
  negative_count: number;
};

type Signal = {
  quarter: string;
  channel: string;
  audience_segment: string;
  signal_kind: string;
  signal_strength: number;
  evidence_quote: string;
  observed_at: string;
};

type Reposition = {
  quarter: string;
  narrative_theme: string;
  tagline: string;
  resonance_score: number;
  verdict: string;
};

type Tagline = {
  quarter: string;
  tagline: string;
  combined_score: number;
  verdict: string;
};

type Verdict = {
  verdict: string;
  narrative_count: number;
  avg_resonance: number;
};

function fmt(n: number | null | undefined) {
  if (n === null || n === undefined) return '-';
  return Number(n).toFixed(2);
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overviewRes, kpiRes, peerRes, channelRes, signalsRes, repositionRes, taglineRes, verdictRes] = await Promise.all([
    supabase.rpc('rpc_r2853_narrative_overview'),
    supabase.rpc('rpc_r2853_kpi_snapshot'),
    supabase.rpc('rpc_r2853_peer_benchmark_table'),
    supabase.rpc('rpc_r2853_resonance_by_channel'),
    supabase.rpc('rpc_r2853_resonance_signals'),
    supabase.rpc('rpc_r2853_reposition_candidates'),
    supabase.rpc('rpc_r2853_tagline_leaderboard'),
    supabase.rpc('rpc_r2853_verdict_distribution'),
  ]);

  const overview: Overview[] = (overviewRes.data ?? []) as Overview[];
  const kpi: Kpi = ((kpiRes.data ?? [])[0] ?? {
    total_quarters: 0,
    crisp_count: 0,
    muddled_count: 0,
    avg_differentiation: 0,
    avg_resonance: 0,
    avg_market_clarity: 0,
  }) as Kpi;
  const peers: Peer[] = (peerRes.data ?? []) as Peer[];
  const channels: ChannelRow[] = (channelRes.data ?? []) as ChannelRow[];
  const signals: Signal[] = (signalsRes.data ?? []) as Signal[];
  const repos: Reposition[] = (repositionRes.data ?? []) as Reposition[];
  const taglines: Tagline[] = (taglineRes.data ?? []) as Tagline[];
  const verdicts: Verdict[] = (verdictRes.data ?? []) as Verdict[];

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-8">
      <header className="space-y-2">
        <h1 className="text-3xl font-bold">Quarterly Strategic Narrative & Bench-Marking</h1>
        <p className="text-sm text-gray-600">
          Narrative theme × peer benchmark × differentiation × tagline resonance × verdict.
          Founder-only console — quarter-over-quarter pitch hygiene.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
        <KpiCard label="Quarters" value={String(kpi.total_quarters)} />
        <KpiCard label="Crisp" value={String(kpi.crisp_count)} />
        <KpiCard label="Muddled" value={String(kpi.muddled_count)} />
        <KpiCard label="Avg Diff" value={fmt(kpi.avg_differentiation)} />
        <KpiCard label="Avg Resonance" value={fmt(kpi.avg_resonance)} />
        <KpiCard label="Avg Clarity" value={fmt(kpi.avg_market_clarity)} />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Narrative Overview</h2>
        <DataTable
          rows={overview}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r: Overview) => r.quarter },
            { key: 'narrative_theme', header: 'Theme', render: (r: Overview) => r.narrative_theme },
            { key: 'tagline', header: 'Tagline', render: (r: Overview) => r.tagline },
            { key: 'verdict', header: 'Verdict', render: (r: Overview) => r.verdict },
            { key: 'differentiation_score', header: 'Diff', render: (r: Overview) => fmt(r.differentiation_score) },
            { key: 'resonance_score', header: 'Resonance', render: (r: Overview) => fmt(r.resonance_score) },
            { key: 'market_clarity_score', header: 'Clarity', render: (r: Overview) => fmt(r.market_clarity_score) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as Overview).quarter ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Peer Benchmark Differentiation</h2>
        <p className="text-sm text-gray-600 mb-2">Sorted by differentiation score (highest first).</p>
        <DataTable
          rows={peers}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r: Peer) => r.quarter },
            { key: 'narrative_theme', header: 'Theme', render: (r: Peer) => r.narrative_theme },
            { key: 'peer_benchmark', header: 'Peer Reference', render: (r: Peer) => r.peer_benchmark },
            { key: 'differentiation_score', header: 'Diff', render: (r: Peer) => fmt(r.differentiation_score) },
            { key: 'verdict', header: 'Verdict', render: (r: Peer) => r.verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as Peer).quarter ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Resonance by Channel</h2>
        <DataTable
          rows={channels}
          columns={[
            { key: 'channel', header: 'Channel', render: (r: ChannelRow) => r.channel },
            { key: 'signal_count', header: 'Signals', render: (r: ChannelRow) => String(r.signal_count) },
            { key: 'avg_strength', header: 'Avg Strength', render: (r: ChannelRow) => fmt(r.avg_strength) },
            { key: 'positive_count', header: 'Positive', render: (r: ChannelRow) => String(r.positive_count) },
            { key: 'negative_count', header: 'Negative', render: (r: ChannelRow) => String(r.negative_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as ChannelRow).channel ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Resonance Signals</h2>
        <DataTable
          rows={signals}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r: Signal) => r.quarter },
            { key: 'channel', header: 'Channel', render: (r: Signal) => r.channel },
            { key: 'audience_segment', header: 'Audience', render: (r: Signal) => r.audience_segment },
            { key: 'signal_kind', header: 'Kind', render: (r: Signal) => r.signal_kind },
            { key: 'signal_strength', header: 'Strength', render: (r: Signal) => fmt(r.signal_strength) },
            { key: 'evidence_quote', header: 'Evidence', render: (r: Signal) => r.evidence_quote },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Tagline Leaderboard</h2>
        <p className="text-sm text-gray-600 mb-2">Combined score = avg(differentiation + resonance + clarity).</p>
        <DataTable
          rows={taglines}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r: Tagline) => r.quarter },
            { key: 'tagline', header: 'Tagline', render: (r: Tagline) => r.tagline },
            { key: 'combined_score', header: 'Combined', render: (r: Tagline) => fmt(r.combined_score) },
            { key: 'verdict', header: 'Verdict', render: (r: Tagline) => r.verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as Tagline).quarter ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Reposition Candidates</h2>
        <p className="text-sm text-gray-600 mb-2">Narratives with resonance &lt;= adequate. Lowest resonance first.</p>
        <DataTable
          rows={repos}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r: Reposition) => r.quarter },
            { key: 'narrative_theme', header: 'Theme', render: (r: Reposition) => r.narrative_theme },
            { key: 'tagline', header: 'Tagline', render: (r: Reposition) => r.tagline },
            { key: 'resonance_score', header: 'Resonance', render: (r: Reposition) => fmt(r.resonance_score) },
            { key: 'verdict', header: 'Verdict', render: (r: Reposition) => r.verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as Reposition).quarter ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Verdict Distribution</h2>
        <DataTable
          rows={verdicts}
          columns={[
            { key: 'verdict', header: 'Verdict', render: (r: Verdict) => r.verdict },
            { key: 'narrative_count', header: 'Count', render: (r: Verdict) => String(r.narrative_count) },
            { key: 'avg_resonance', header: 'Avg Resonance', render: (r: Verdict) => fmt(r.avg_resonance) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as Verdict).verdict ?? i)}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="border rounded-lg p-4 bg-white shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="text-2xl font-bold mt-1">{value}</div>
    </div>
  );
}
