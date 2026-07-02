import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ScoreRow = {
  id: string;
  engineer_name: string;
  hospital_name: string;
  csat_score: number;
  csat_response_count: number;
  repeat_request_count: number;
  repeat_request_ratio: number;
  name_recall_count: number;
  name_recall_ratio: number;
  tenure_months: number;
  composite_strength_score: number;
  strength_band: string;
  last_interaction_at: string | null;
  computed_at: string;
};

type BandRow = {
  strength_band: string;
  relationship_count: number;
  avg_score: number;
  avg_tenure_months: number;
};

type TopRow = {
  id: string;
  engineer_name: string;
  hospital_name: string;
  composite_strength_score: number;
  strength_band: string;
  csat_score: number;
  tenure_months: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const { data: scoresData } = await supabase
    .from('engineer_customer_relationship_scores_r2370')
    .select('*')
    .order('composite_strength_score', { ascending: false })
    .limit(200);

  const scores: ScoreRow[] = (scoresData ?? []) as ScoreRow[];

  const { data: bandData } = await supabase.rpc('engineer_customer_strength_band_summary_r2370');
  const bands: BandRow[] = (bandData ?? []) as BandRow[];

  const { data: topData } = await supabase.rpc('top_engineer_customer_relationships_r2370', { p_limit: 10 });
  const top: TopRow[] = (topData ?? []) as TopRow[];

  const totalRels = scores.length;
  const avgScore = totalRels > 0
    ? (scores.reduce((s, r) => s + Number(r.composite_strength_score ?? 0), 0) / totalRels).toFixed(2)
    : '0.00';
  const platinumCount = scores.filter((r) => r.strength_band === 'platinum').length;
  const coldCount = scores.filter((r) => r.strength_band === 'cold').length;

  const scoreColumns: Column<ScoreRow>[] = [
    { key: 'engineer', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'hospital', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'csat', header: 'CSAT', render: (r) => `${Number(r.csat_score).toFixed(2)} (${r.csat_response_count})` },
    { key: 'repeat', header: 'Repeat %', render: (r) => `${Number(r.repeat_request_ratio).toFixed(1)}% (${r.repeat_request_count})` },
    { key: 'recall', header: 'Recall %', render: (r) => `${Number(r.name_recall_ratio).toFixed(1)}% (${r.name_recall_count})` },
    { key: 'tenure', header: 'Tenure (mo)', render: (r) => String(r.tenure_months) },
    { key: 'score', header: 'Score', render: (r) => Number(r.composite_strength_score).toFixed(2) },
    { key: 'band', header: 'Band', render: (r) => r.strength_band },
    { key: 'last', header: 'Last interaction', render: (r) => (r.last_interaction_at ? new Date(r.last_interaction_at).toLocaleDateString() : '—') },
  ];

  const bandColumns: Column<BandRow>[] = [
    { key: 'band', header: 'Band', render: (r) => r.strength_band },
    { key: 'count', header: 'Relationships', render: (r) => String(r.relationship_count) },
    { key: 'avg', header: 'Avg score', render: (r) => Number(r.avg_score ?? 0).toFixed(2) },
    { key: 'tenure', header: 'Avg tenure (mo)', render: (r) => Number(r.avg_tenure_months ?? 0).toFixed(1) },
  ];

  const topColumns: Column<TopRow>[] = [
    { key: 'engineer', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'hospital', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'score', header: 'Score', render: (r) => Number(r.composite_strength_score).toFixed(2) },
    { key: 'band', header: 'Band', render: (r) => r.strength_band },
    { key: 'csat', header: 'CSAT', render: (r) => Number(r.csat_score).toFixed(2) },
    { key: 'tenure', header: 'Tenure (mo)', render: (r) => String(r.tenure_months) },
  ];

  return (
    <div className="space-y-6 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-bold">Engineer customer-relationship strength score</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Composite strength = CSAT &amp; repeat-request &amp; name-recall &amp; tenure. Bands: platinum &gt;= 85, gold &gt;= 70, silver &gt;= 55, bronze &gt;= 35, cold &lt; 35.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs text-[var(--color-muted)]">Total relationships</div>
          <div className="text-xl font-semibold">{totalRels}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs text-[var(--color-muted)]">Avg strength</div>
          <div className="text-xl font-semibold">{avgScore}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs text-[var(--color-muted)]">Platinum</div>
          <div className="text-xl font-semibold">{platinumCount}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs text-[var(--color-muted)]">Cold (at-risk)</div>
          <div className="text-xl font-semibold">{coldCount}</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Band summary</h2>
        <DataTable<BandRow>
          columns={bandColumns}
          rows={bands}
          emptyMessage="No band data yet."
          rowKey={(r) => r.strength_band}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Top 10 relationships</h2>
        <DataTable<TopRow>
          columns={topColumns}
          rows={top}
          emptyMessage="No top relationships yet."
          rowKey={(r) => r.id}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">All relationships</h2>
        <DataTable<ScoreRow>
          columns={scoreColumns}
          rows={scores}
          emptyMessage="No relationships scored yet."
          rowKey={(r) => r.id}
        />
      </section>
    </div>
  );
}
