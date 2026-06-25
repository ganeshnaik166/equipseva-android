import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Pillar = {
  id: string;
  pillar_code: string;
  pillar_name: string;
  category: string;
  weight_pct: number;
  current_score: number;
  target_score: number;
  evidence_summary: string;
  gap_summary: string;
  close_action: string;
  owner: string;
  target_round: number;
  decision: string;
  reviewed_at: string;
};

type Evidence = {
  id: string;
  pillar_code: string;
  evidence_kind: string;
  evidence_title: string;
  evidence_value: string;
  source_url: string | null;
  strength: string;
  collected_at: string;
  verified: boolean;
  notes: string | null;
};

type Summary = {
  total_pillars: number;
  weighted_current: number;
  weighted_target: number;
  gap_points: number;
  blockers: number;
  ship_now: number;
};

type CategoryRow = {
  category: string;
  pillars: number;
  avg_current: number;
  avg_target: number;
  avg_gap: number;
};

type StrengthRow = {
  strength: string;
  evidence_count: number;
  verified_count: number;
};

type RoundRow = {
  target_round: number;
  pillar_code: string;
  pillar_name: string;
  decision: string;
  gap_points: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [pillarsRes, summaryRes, blockersRes, evidenceRes, categoryRes, strengthRes, roundsRes, unverifiedRes] = await Promise.all([
    supabase.rpc('get_fundraise_pillars_r2713'),
    supabase.rpc('get_fundraise_score_summary_r2713'),
    supabase.rpc('get_fundraise_blockers_r2713'),
    supabase.rpc('get_fundraise_evidence_r2713'),
    supabase.rpc('get_fundraise_by_category_r2713'),
    supabase.rpc('get_fundraise_evidence_strength_r2713'),
    supabase.rpc('get_fundraise_target_rounds_r2713'),
    supabase.rpc('get_fundraise_unverified_evidence_r2713'),
  ]);

  const pillars: Pillar[] = (pillarsRes.data as Pillar[]) ?? [];
  const summary: Summary = ((summaryRes.data as Summary[]) ?? [])[0] ?? {
    total_pillars: 0,
    weighted_current: 0,
    weighted_target: 0,
    gap_points: 0,
    blockers: 0,
    ship_now: 0,
  };
  const blockers: Pillar[] = (blockersRes.data as Pillar[]) ?? [];
  const evidence: Evidence[] = (evidenceRes.data as Evidence[]) ?? [];
  const categories: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const strengths: StrengthRow[] = (strengthRes.data as StrengthRow[]) ?? [];
  const rounds: RoundRow[] = (roundsRes.data as RoundRow[]) ?? [];
  const unverified: Evidence[] = (unverifiedRes.data as Evidence[]) ?? [];

  const pillarCols = [
    { key: 'pillar_code', header: 'Code', render: (r: Pillar) => r.pillar_code },
    { key: 'pillar_name', header: 'Pillar', render: (r: Pillar) => r.pillar_name },
    { key: 'category', header: 'Category', render: (r: Pillar) => r.category },
    { key: 'weight_pct', header: 'Weight %', render: (r: Pillar) => `${r.weight_pct}%` },
    { key: 'current_score', header: 'Now', render: (r: Pillar) => String(r.current_score) },
    { key: 'target_score', header: 'Target', render: (r: Pillar) => String(r.target_score) },
    { key: 'gap', header: 'Gap', render: (r: Pillar) => String(r.target_score - r.current_score) },
    { key: 'decision', header: 'Decision', render: (r: Pillar) => r.decision },
    { key: 'target_round', header: 'Target r', render: (r: Pillar) => `r${r.target_round}` },
    { key: 'owner', header: 'Owner', render: (r: Pillar) => r.owner },
  ];

  const blockerCols = [
    { key: 'pillar_name', header: 'Pillar', render: (r: Pillar) => r.pillar_name },
    { key: 'gap_summary', header: 'Gap', render: (r: Pillar) => r.gap_summary },
    { key: 'close_action', header: 'Close action', render: (r: Pillar) => r.close_action },
    { key: 'owner', header: 'Owner', render: (r: Pillar) => r.owner },
    { key: 'target_round', header: 'Target r', render: (r: Pillar) => `r${r.target_round}` },
    { key: 'decision', header: 'Decision', render: (r: Pillar) => r.decision },
  ];

  const evidenceCols = [
    { key: 'pillar_code', header: 'Pillar', render: (r: Evidence) => r.pillar_code },
    { key: 'evidence_kind', header: 'Kind', render: (r: Evidence) => r.evidence_kind },
    { key: 'evidence_title', header: 'Title', render: (r: Evidence) => r.evidence_title },
    { key: 'evidence_value', header: 'Value', render: (r: Evidence) => r.evidence_value },
    { key: 'strength', header: 'Strength', render: (r: Evidence) => r.strength },
    { key: 'verified', header: 'Verified', render: (r: Evidence) => (r.verified ? 'yes' : 'no') },
    { key: 'collected_at', header: 'Collected', render: (r: Evidence) => r.collected_at },
  ];

  const categoryCols = [
    { key: 'category', header: 'Category', render: (r: CategoryRow) => r.category },
    { key: 'pillars', header: 'Pillars', render: (r: CategoryRow) => String(r.pillars) },
    { key: 'avg_current', header: 'Avg now', render: (r: CategoryRow) => String(r.avg_current) },
    { key: 'avg_target', header: 'Avg target', render: (r: CategoryRow) => String(r.avg_target) },
    { key: 'avg_gap', header: 'Avg gap', render: (r: CategoryRow) => String(r.avg_gap) },
  ];

  const strengthCols = [
    { key: 'strength', header: 'Strength', render: (r: StrengthRow) => r.strength },
    { key: 'evidence_count', header: 'Count', render: (r: StrengthRow) => String(r.evidence_count) },
    { key: 'verified_count', header: 'Verified', render: (r: StrengthRow) => String(r.verified_count) },
  ];

  const roundCols = [
    { key: 'target_round', header: 'Target r', render: (r: RoundRow) => `r${r.target_round}` },
    { key: 'pillar_code', header: 'Pillar', render: (r: RoundRow) => r.pillar_code },
    { key: 'pillar_name', header: 'Name', render: (r: RoundRow) => r.pillar_name },
    { key: 'decision', header: 'Decision', render: (r: RoundRow) => r.decision },
    { key: 'gap_points', header: 'Gap pts', render: (r: RoundRow) => String(r.gap_points) },
  ];

  const unverifiedCols = [
    { key: 'pillar_code', header: 'Pillar', render: (r: Evidence) => r.pillar_code },
    { key: 'evidence_title', header: 'Title', render: (r: Evidence) => r.evidence_title },
    { key: 'evidence_kind', header: 'Kind', render: (r: Evidence) => r.evidence_kind },
    { key: 'strength', header: 'Strength', render: (r: Evidence) => r.strength },
    { key: 'collected_at', header: 'Collected', render: (r: Evidence) => r.collected_at },
  ];

  return (
    <main className="p-6 space-y-8 max-w-7xl mx-auto">
      <header className="space-y-2">
        <h1 className="text-3xl font-bold">Founder Quarterly Fundraise Readiness Score</h1>
        <p className="text-sm text-gray-600">
          Pillar × score × evidence × gap × close action × target round × decision. Weighted current vs target across {summary.total_pillars} pillars.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-6 gap-4">
        <KpiCard label="Pillars" value={String(summary.total_pillars)} />
        <KpiCard label="Weighted now" value={String(summary.weighted_current)} />
        <KpiCard label="Weighted target" value={String(summary.weighted_target)} />
        <KpiCard label="Gap pts" value={String(summary.gap_points)} />
        <KpiCard label="Blockers" value={String(summary.blockers)} tone="red" />
        <KpiCard label="Ship now" value={String(summary.ship_now)} tone="green" />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Pillar scorecard</h2>
        <p className="text-sm text-gray-600">All pillars ranked by weight. Gap = target − current.</p>
        <DataTable rows={pillars} columns={pillarCols} emptyMessage="No data" rowKey={(r: Pillar, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Blockers & accelerate</h2>
        <p className="text-sm text-gray-600">Pillars flagged as blocker or accelerate — close before next term sheet.</p>
        <DataTable rows={blockers} columns={blockerCols} emptyMessage="No data" rowKey={(r: Pillar, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">By category</h2>
        <DataTable rows={categories} columns={categoryCols} emptyMessage="No data" rowKey={(r: CategoryRow, i: number) => String(r.category ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Evidence strength mix</h2>
        <DataTable rows={strengths} columns={strengthCols} emptyMessage="No data" rowKey={(r: StrengthRow, i: number) => String(r.strength ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Target rounds (close sequencing)</h2>
        <DataTable rows={rounds} columns={roundCols} emptyMessage="No data" rowKey={(r: RoundRow, i: number) => String(r.pillar_code ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Evidence library</h2>
        <DataTable rows={evidence} columns={evidenceCols} emptyMessage="No data" rowKey={(r: Evidence, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Unverified evidence (chase)</h2>
        <DataTable rows={unverified} columns={unverifiedCols} emptyMessage="No data" rowKey={(r: Evidence, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}

function KpiCard({ label, value, tone }: { label: string; value: string; tone?: 'red' | 'green' }) {
  const toneClass = tone === 'red' ? 'text-red-700' : tone === 'green' ? 'text-green-700' : 'text-gray-900';
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className={`mt-1 text-2xl font-bold ${toneClass}`}>{value}</div>
    </div>
  );
}
