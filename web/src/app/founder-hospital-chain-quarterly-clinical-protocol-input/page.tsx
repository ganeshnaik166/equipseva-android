import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_chains: number;
  total_recommendations: number;
  adopted_count: number;
  piloting_count: number;
  proposed_count: number;
  revising_count: number;
  avg_adoption_percent: number | null;
  avg_outcome_delta: number | null;
};

type ProtocolRow = {
  id: string;
  chain_name: string;
  chain_tier: string;
  protocol_area: string;
  our_recommendation: string;
  evidence_grade: string;
  adoption_status: string;
  adoption_percent: number;
  clinical_outcome_delta_percent: number | null;
  champion_clinician: string | null;
  decision_due_at: string;
};

type StatusRow = {
  adoption_status: string;
  recommendation_count: number;
  avg_adoption: number | null;
  avg_outcome_delta: number | null;
};

type TierRow = {
  chain_tier: string;
  chain_count: number;
  adopted_count: number;
  avg_outcome_delta: number | null;
};

type OutcomeLogRow = {
  id: string;
  chain_name: string;
  protocol_area: string;
  recorded_on: string;
  outcome_metric: string;
  baseline_value: number;
  current_value: number;
  delta_percent: number;
  outcome_grade: string;
  hospitals_adopted: number;
  hospitals_total: number;
};

type TopWinRow = {
  chain_name: string;
  protocol_area: string;
  our_recommendation: string;
  clinical_outcome_delta_percent: number;
  story: string;
};

type PendingRow = {
  chain_name: string;
  protocol_area: string;
  our_recommendation: string;
  adoption_status: string;
  decision_due_at: string;
  days_until_due: number;
  champion_clinician: string | null;
};

type EvidenceRow = {
  evidence_grade: string;
  recommendation_count: number;
  adoption_percent_avg: number | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overviewRes, listRes, statusRes, tierRes, logsRes, winsRes, pendingRes, evidenceRes] = await Promise.all([
    supabase.rpc('founder_chain_protocol_overview_r2739'),
    supabase.rpc('founder_chain_protocol_list_r2739'),
    supabase.rpc('founder_chain_protocol_by_status_r2739'),
    supabase.rpc('founder_chain_protocol_by_tier_r2739'),
    supabase.rpc('founder_chain_protocol_outcome_logs_r2739'),
    supabase.rpc('founder_chain_protocol_top_wins_r2739'),
    supabase.rpc('founder_chain_protocol_pending_decisions_r2739'),
    supabase.rpc('founder_chain_protocol_evidence_grade_mix_r2739'),
  ]);

  const overview: Overview | null = (overviewRes.data?.[0] as Overview) ?? null;
  const protocols: ProtocolRow[] = (listRes.data as ProtocolRow[]) ?? [];
  const byStatus: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const byTier: TierRow[] = (tierRes.data as TierRow[]) ?? [];
  const logs: OutcomeLogRow[] = (logsRes.data as OutcomeLogRow[]) ?? [];
  const wins: TopWinRow[] = (winsRes.data as TopWinRow[]) ?? [];
  const pending: PendingRow[] = (pendingRes.data as PendingRow[]) ?? [];
  const evidence: EvidenceRow[] = (evidenceRes.data as EvidenceRow[]) ?? [];

  return (
    <div className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">Hospital Chain Quarterly Clinical Protocol Input</h1>
        <p className="text-sm text-neutral-600">
          Per-chain protocol recommendations, adoption status, and clinical outcome deltas. Adoption percent &gt;= 75 marks a chain-wide win.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <KpiCard label="Chains" value={overview?.total_chains ?? 0} />
        <KpiCard label="Recommendations" value={overview?.total_recommendations ?? 0} />
        <KpiCard label="Adopted" value={overview?.adopted_count ?? 0} />
        <KpiCard label="Piloting" value={overview?.piloting_count ?? 0} />
        <KpiCard label="Proposed" value={overview?.proposed_count ?? 0} />
        <KpiCard label="Revising" value={overview?.revising_count ?? 0} />
        <KpiCard label="Avg adoption %" value={overview?.avg_adoption_percent ?? 0} />
        <KpiCard label="Avg outcome delta %" value={overview?.avg_outcome_delta ?? 0} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">All protocol recommendations</h2>
        <DataTable
          rows={protocols}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ProtocolRow) => r.chain_name },
            { key: 'chain_tier', header: 'Tier', render: (r: ProtocolRow) => r.chain_tier },
            { key: 'protocol_area', header: 'Protocol area', render: (r: ProtocolRow) => r.protocol_area },
            { key: 'our_recommendation', header: 'Our recommendation', render: (r: ProtocolRow) => r.our_recommendation },
            { key: 'evidence_grade', header: 'Evidence', render: (r: ProtocolRow) => r.evidence_grade },
            { key: 'adoption_status', header: 'Status', render: (r: ProtocolRow) => r.adoption_status },
            { key: 'adoption_percent', header: 'Adoption %', render: (r: ProtocolRow) => String(r.adoption_percent) },
            { key: 'clinical_outcome_delta_percent', header: 'Outcome delta %', render: (r: ProtocolRow) => r.clinical_outcome_delta_percent == null ? '-' : String(r.clinical_outcome_delta_percent) },
            { key: 'champion_clinician', header: 'Champion', render: (r: ProtocolRow) => r.champion_clinician ?? '-' },
            { key: 'decision_due_at', header: 'Decision due', render: (r: ProtocolRow) => r.decision_due_at },
          ]}
          emptyMessage="No data"
          rowKey={(r: ProtocolRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid gap-6 md:grid-cols-2">
        <div className="space-y-3">
          <h2 className="text-lg font-medium">Adoption status mix</h2>
          <DataTable
            rows={byStatus}
            columns={[
              { key: 'adoption_status', header: 'Status', render: (r: StatusRow) => r.adoption_status },
              { key: 'recommendation_count', header: 'Count', render: (r: StatusRow) => String(r.recommendation_count) },
              { key: 'avg_adoption', header: 'Avg adoption %', render: (r: StatusRow) => r.avg_adoption == null ? '-' : String(r.avg_adoption) },
              { key: 'avg_outcome_delta', header: 'Avg outcome delta %', render: (r: StatusRow) => r.avg_outcome_delta == null ? '-' : String(r.avg_outcome_delta) },
            ]}
            emptyMessage="No data"
            rowKey={(r: StatusRow, i: number) => String(r.adoption_status ?? i)}
          />
        </div>
        <div className="space-y-3">
          <h2 className="text-lg font-medium">Tier breakdown</h2>
          <DataTable
            rows={byTier}
            columns={[
              { key: 'chain_tier', header: 'Tier', render: (r: TierRow) => r.chain_tier },
              { key: 'chain_count', header: 'Chains', render: (r: TierRow) => String(r.chain_count) },
              { key: 'adopted_count', header: 'Adopted', render: (r: TierRow) => String(r.adopted_count) },
              { key: 'avg_outcome_delta', header: 'Avg outcome delta %', render: (r: TierRow) => r.avg_outcome_delta == null ? '-' : String(r.avg_outcome_delta) },
            ]}
            emptyMessage="No data"
            rowKey={(r: TierRow, i: number) => String(r.chain_tier ?? i)}
          />
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Outcome logs (Q2)</h2>
        <DataTable
          rows={logs}
          columns={[
            { key: 'recorded_on', header: 'Date', render: (r: OutcomeLogRow) => r.recorded_on },
            { key: 'chain_name', header: 'Chain', render: (r: OutcomeLogRow) => r.chain_name },
            { key: 'protocol_area', header: 'Protocol', render: (r: OutcomeLogRow) => r.protocol_area },
            { key: 'outcome_metric', header: 'Metric', render: (r: OutcomeLogRow) => r.outcome_metric },
            { key: 'baseline_value', header: 'Baseline', render: (r: OutcomeLogRow) => String(r.baseline_value) },
            { key: 'current_value', header: 'Current', render: (r: OutcomeLogRow) => String(r.current_value) },
            { key: 'delta_percent', header: 'Delta %', render: (r: OutcomeLogRow) => String(r.delta_percent) },
            { key: 'outcome_grade', header: 'Grade', render: (r: OutcomeLogRow) => r.outcome_grade },
            { key: 'hospitals_adopted', header: 'Hospitals adopted / total', render: (r: OutcomeLogRow) => `${r.hospitals_adopted} / ${r.hospitals_total}` },
          ]}
          emptyMessage="No data"
          rowKey={(r: OutcomeLogRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Top wins (clinical outcome &gt;= 10%)</h2>
        <DataTable
          rows={wins}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: TopWinRow) => r.chain_name },
            { key: 'protocol_area', header: 'Protocol', render: (r: TopWinRow) => r.protocol_area },
            { key: 'our_recommendation', header: 'Recommendation', render: (r: TopWinRow) => r.our_recommendation },
            { key: 'clinical_outcome_delta_percent', header: 'Outcome delta %', render: (r: TopWinRow) => String(r.clinical_outcome_delta_percent) },
            { key: 'story', header: 'Story', render: (r: TopWinRow) => r.story },
          ]}
          emptyMessage="No data"
          rowKey={(r: TopWinRow, i: number) => String(`${r.chain_name}-${r.protocol_area}-${i}`)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Pending decisions</h2>
        <DataTable
          rows={pending}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: PendingRow) => r.chain_name },
            { key: 'protocol_area', header: 'Protocol', render: (r: PendingRow) => r.protocol_area },
            { key: 'our_recommendation', header: 'Recommendation', render: (r: PendingRow) => r.our_recommendation },
            { key: 'adoption_status', header: 'Status', render: (r: PendingRow) => r.adoption_status },
            { key: 'decision_due_at', header: 'Due', render: (r: PendingRow) => r.decision_due_at },
            { key: 'days_until_due', header: 'Days left', render: (r: PendingRow) => String(r.days_until_due) },
            { key: 'champion_clinician', header: 'Champion', render: (r: PendingRow) => r.champion_clinician ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: PendingRow, i: number) => String(`${r.chain_name}-${r.protocol_area}-${i}`)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Evidence grade mix</h2>
        <DataTable
          rows={evidence}
          columns={[
            { key: 'evidence_grade', header: 'Grade', render: (r: EvidenceRow) => r.evidence_grade },
            { key: 'recommendation_count', header: 'Count', render: (r: EvidenceRow) => String(r.recommendation_count) },
            { key: 'adoption_percent_avg', header: 'Avg adoption %', render: (r: EvidenceRow) => r.adoption_percent_avg == null ? '-' : String(r.adoption_percent_avg) },
          ]}
          emptyMessage="No data"
          rowKey={(r: EvidenceRow, i: number) => String(r.evidence_grade ?? i)}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-4">
      <div className="text-xs uppercase tracking-wide text-neutral-500">{label}</div>
      <div className="mt-1 text-2xl font-semibold tabular-nums">{value}</div>
    </div>
  );
}