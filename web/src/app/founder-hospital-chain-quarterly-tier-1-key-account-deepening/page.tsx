import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Summary = {
  total_plays: number;
  total_commit_rupees: number;
  total_landed_rupees: number;
  avg_renewal_pct: number;
  at_risk_count: number;
};

type ByChain = {
  chain_name: string;
  play_count: number;
  commit_rupees: number;
  landed_rupees: number;
  avg_renewal_pct: number;
};

type ByOutcome = {
  outcome_status: string;
  cnt: number;
  commit_rupees: number;
  outcome_rupees: number;
};

type PlayFull = {
  id: string;
  chain_name: string;
  tier1_sub_account: string;
  quarter: string;
  deepen_play: string;
  exec_commit_amount_rupees: number;
  outcome_status: string;
  outcome_value_rupees: number;
  renewal_probability_pct: number;
  account_owner: string;
  next_review_on: string;
};

type SignalFull = {
  id: string;
  chain_name: string;
  tier1_sub_account: string;
  signal_kind: string;
  signal_strength: string;
  detail: string;
  observed_on: string;
  action_taken: string;
};

type Risk = {
  chain_name: string;
  tier1_sub_account: string;
  deepen_play: string;
  outcome_status: string;
  renewal_probability_pct: number;
  account_owner: string;
};

type Review = {
  chain_name: string;
  tier1_sub_account: string;
  next_review_on: string;
  account_owner: string;
  outcome_status: string;
};

function rupees(v: number | null | undefined): string {
  const n = Number(v ?? 0);
  return '₹' + n.toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, byChainRes, byOutcomeRes, playsRes, signalsRes, risksRes, reviewsRes] = await Promise.all([
    supabase.rpc('rpc_r2831_play_summary'),
    supabase.rpc('rpc_r2831_plays_by_chain'),
    supabase.rpc('rpc_r2831_plays_by_outcome'),
    supabase.rpc('rpc_r2831_plays_full'),
    supabase.rpc('rpc_r2831_signals_full'),
    supabase.rpc('rpc_r2831_top_renewal_risks'),
    supabase.rpc('rpc_r2831_upcoming_reviews'),
  ]);

  const summary: Summary = (summaryRes.data?.[0] as Summary) ?? {
    total_plays: 0,
    total_commit_rupees: 0,
    total_landed_rupees: 0,
    avg_renewal_pct: 0,
    at_risk_count: 0,
  };
  const byChain: ByChain[] = (byChainRes.data as ByChain[]) ?? [];
  const byOutcome: ByOutcome[] = (byOutcomeRes.data as ByOutcome[]) ?? [];
  const plays: PlayFull[] = (playsRes.data as PlayFull[]) ?? [];
  const signals: SignalFull[] = (signalsRes.data as SignalFull[]) ?? [];
  const risks: Risk[] = (risksRes.data as Risk[]) ?? [];
  const reviews: Review[] = (reviewsRes.data as Review[]) ?? [];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Hospital Chain Quarterly Tier-1 Key Account Deepening
      </h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Chain × tier-1 sub × deepen play × commit × outcome × renewal probability. Anything with renewal &lt;= 70 percent surfaces in the risk panel.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <KpiCard label="Total plays" value={String(summary.total_plays ?? 0)} />
        <KpiCard label="Commit value" value={rupees(summary.total_commit_rupees)} />
        <KpiCard label="Landed value" value={rupees(summary.total_landed_rupees)} />
        <KpiCard label="Avg renewal probability" value={String(summary.avg_renewal_pct ?? 0) + ' %'} />
        <KpiCard label="At-risk plays" value={String(summary.at_risk_count ?? 0)} />
      </div>

      <Section title="By chain">
        <DataTable
          rows={byChain}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ByChain) => r.chain_name },
            { key: 'play_count', header: 'Plays', render: (r: ByChain) => String(r.play_count) },
            { key: 'commit_rupees', header: 'Commit', render: (r: ByChain) => rupees(r.commit_rupees) },
            { key: 'landed_rupees', header: 'Landed', render: (r: ByChain) => rupees(r.landed_rupees) },
            { key: 'avg_renewal_pct', header: 'Avg renewal %', render: (r: ByChain) => String(r.avg_renewal_pct) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as ByChain).chain_name ?? i)}
        />
      </Section>

      <Section title="By outcome">
        <DataTable
          rows={byOutcome}
          columns={[
            { key: 'outcome_status', header: 'Outcome', render: (r: ByOutcome) => r.outcome_status },
            { key: 'cnt', header: 'Count', render: (r: ByOutcome) => String(r.cnt) },
            { key: 'commit_rupees', header: 'Commit', render: (r: ByOutcome) => rupees(r.commit_rupees) },
            { key: 'outcome_rupees', header: 'Outcome value', render: (r: ByOutcome) => rupees(r.outcome_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as ByOutcome).outcome_status ?? i)}
        />
      </Section>

      <Section title="Renewal risks (probability <= 70 percent)">
        <DataTable
          rows={risks}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Risk) => r.chain_name },
            { key: 'tier1_sub_account', header: 'Tier-1 sub', render: (r: Risk) => r.tier1_sub_account },
            { key: 'deepen_play', header: 'Play', render: (r: Risk) => r.deepen_play },
            { key: 'outcome_status', header: 'Outcome', render: (r: Risk) => r.outcome_status },
            { key: 'renewal_probability_pct', header: 'Renewal %', render: (r: Risk) => String(r.renewal_probability_pct) },
            { key: 'account_owner', header: 'Owner', render: (r: Risk) => r.account_owner },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(i)}
        />
      </Section>

      <Section title="Upcoming reviews">
        <DataTable
          rows={reviews}
          columns={[
            { key: 'next_review_on', header: 'Date', render: (r: Review) => r.next_review_on },
            { key: 'chain_name', header: 'Chain', render: (r: Review) => r.chain_name },
            { key: 'tier1_sub_account', header: 'Tier-1 sub', render: (r: Review) => r.tier1_sub_account },
            { key: 'account_owner', header: 'Owner', render: (r: Review) => r.account_owner },
            { key: 'outcome_status', header: 'Outcome', render: (r: Review) => r.outcome_status },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(i)}
        />
      </Section>

      <Section title="All plays">
        <DataTable
          rows={plays}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: PlayFull) => r.chain_name },
            { key: 'tier1_sub_account', header: 'Tier-1 sub', render: (r: PlayFull) => r.tier1_sub_account },
            { key: 'quarter', header: 'Quarter', render: (r: PlayFull) => r.quarter },
            { key: 'deepen_play', header: 'Deepen play', render: (r: PlayFull) => r.deepen_play },
            { key: 'exec_commit_amount_rupees', header: 'Commit', render: (r: PlayFull) => rupees(r.exec_commit_amount_rupees) },
            { key: 'outcome_status', header: 'Outcome', render: (r: PlayFull) => r.outcome_status },
            { key: 'outcome_value_rupees', header: 'Outcome value', render: (r: PlayFull) => rupees(r.outcome_value_rupees) },
            { key: 'renewal_probability_pct', header: 'Renewal %', render: (r: PlayFull) => String(r.renewal_probability_pct) },
            { key: 'account_owner', header: 'Owner', render: (r: PlayFull) => r.account_owner },
            { key: 'next_review_on', header: 'Next review', render: (r: PlayFull) => r.next_review_on },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as PlayFull).id ?? i)}
        />
      </Section>

      <Section title="Account signals">
        <DataTable
          rows={signals}
          columns={[
            { key: 'observed_on', header: 'Date', render: (r: SignalFull) => r.observed_on },
            { key: 'chain_name', header: 'Chain', render: (r: SignalFull) => r.chain_name },
            { key: 'tier1_sub_account', header: 'Tier-1 sub', render: (r: SignalFull) => r.tier1_sub_account },
            { key: 'signal_kind', header: 'Kind', render: (r: SignalFull) => r.signal_kind },
            { key: 'signal_strength', header: 'Strength', render: (r: SignalFull) => r.signal_strength },
            { key: 'detail', header: 'Detail', render: (r: SignalFull) => r.detail },
            { key: 'action_taken', header: 'Action', render: (r: SignalFull) => r.action_taken },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as SignalFull).id ?? i)}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 18, fontWeight: 600 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 10 }}>{title}</h2>
      {children}
    </section>
  );
}
