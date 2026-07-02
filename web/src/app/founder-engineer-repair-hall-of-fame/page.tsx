import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type RepairRow = {
  id: string;
  engineer_user_id: string | null;
  engineer_email: string | null;
  repair_job_id: string | null;
  repair_complexity_score: number | null;
  hospital_user_id: string | null;
  hospital_email: string | null;
  story_md: string | null;
  marketing_use: boolean | null;
  status: string | null;
  featured_at: string | null;
  created_at: string | null;
};

type NominationRow = {
  id: string;
  repair_id: string | null;
  nominator_email: string | null;
  nomination_reason: string | null;
  recorded_at: string | null;
};

type TopRow = {
  id: string;
  engineer_user_id: string | null;
  engineer_email: string | null;
  repair_complexity_score: number | null;
  status: string | null;
  story_md: string | null;
  created_at: string | null;
};

type FeaturedRow = {
  id: string;
  engineer_user_id: string | null;
  engineer_email: string | null;
  repair_complexity_score: number | null;
  story_md: string | null;
  marketing_use: boolean | null;
  featured_at: string | null;
};

function fmtDate(s: string | null | undefined) {
  if (!s) return '-';
  try {
    return new Date(s).toLocaleString();
  } catch {
    return s;
  }
}

function truncate(s: string | null | undefined, n = 80) {
  if (!s) return '-';
  return s.length > n ? s.slice(0, n) + '...' : s;
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [repairsRes, nomsRes, topRes, featRes] = await Promise.all([
    sb.rpc('list_repairs_r1864'),
    sb.rpc('list_nominations_r1864'),
    sb.rpc('top_complexity_r1864'),
    sb.rpc('recently_featured_r1864'),
  ]);

  const repairs: RepairRow[] = (repairsRes.data as RepairRow[] | null) ?? [];
  const noms: NominationRow[] = (nomsRes.data as NominationRow[] | null) ?? [];
  const top: TopRow[] = (topRes.data as TopRow[] | null) ?? [];
  const featured: FeaturedRow[] = (featRes.data as FeaturedRow[] | null) ?? [];

  const repairCols: Column<RepairRow>[] = [
    { key: 'engineer', header: 'Engineer', render: (r: any) => r.engineer_email ?? r.engineer_user_id ?? '-' },
    { key: 'complexity', header: 'Complexity', render: (r: any) => String(r.repair_complexity_score ?? '-') },
    { key: 'hospital', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'marketing', header: 'Marketing', render: (r: any) => (r.marketing_use ? 'yes' : 'no') },
    { key: 'story', header: 'Story', render: (r: any) => truncate(r.story_md) },
    { key: 'featured_at', header: 'Featured', render: (r: any) => fmtDate(r.featured_at) },
    { key: 'created_at', header: 'Created', render: (r: any) => fmtDate(r.created_at) },
  ];

  const nomCols: Column<NominationRow>[] = [
    { key: 'repair_id', header: 'Repair', render: (r: any) => r.repair_id ?? '-' },
    { key: 'nominator', header: 'Nominator', render: (r: any) => r.nominator_email ?? '-' },
    { key: 'reason', header: 'Reason', render: (r: any) => truncate(r.nomination_reason) },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => fmtDate(r.recorded_at) },
  ];

  const topCols: Column<TopRow>[] = [
    { key: 'engineer', header: 'Engineer', render: (r: any) => r.engineer_email ?? r.engineer_user_id ?? '-' },
    { key: 'complexity', header: 'Score', render: (r: any) => String(r.repair_complexity_score ?? '-') },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'story', header: 'Story', render: (r: any) => truncate(r.story_md) },
    { key: 'created_at', header: 'Created', render: (r: any) => fmtDate(r.created_at) },
  ];

  const featCols: Column<FeaturedRow>[] = [
    { key: 'engineer', header: 'Engineer', render: (r: any) => r.engineer_email ?? r.engineer_user_id ?? '-' },
    { key: 'complexity', header: 'Score', render: (r: any) => String(r.repair_complexity_score ?? '-') },
    { key: 'marketing', header: 'Marketing', render: (r: any) => (r.marketing_use ? 'yes' : 'no') },
    { key: 'story', header: 'Story', render: (r: any) => truncate(r.story_md) },
    { key: 'featured_at', header: 'Featured', render: (r: any) => fmtDate(r.featured_at) },
  ];

  const totalCount = repairs.length;
  const featuredCount = repairs.filter((r) => r.status === 'featured').length;
  const nominatedCount = repairs.filter((r) => r.status === 'nominated').length;

  return (
    <div className="space-y-8 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Engineer Equipment Repair Hall of Fame</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Celebrate hardest & most-impactful engineer repairs as marketing case studies.
        </p>
        <div className="flex gap-4 text-sm">
          <span>Total: {totalCount}</span>
          <span>Featured: {featuredCount}</span>
          <span>Nominated: {nominatedCount}</span>
        </div>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">All repairs (complexity score &gt;= 1)</h2>
        <DataTable<RepairRow>
          rows={repairs}
          columns={repairCols}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No repairs nominated yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Top complexity (top 25, score &gt; rest)</h2>
        <DataTable<TopRow>
          rows={top}
          columns={topCols}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No top-complexity entries."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recently featured</h2>
        <DataTable<FeaturedRow>
          rows={featured}
          columns={featCols}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No featured repairs yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Nominations log</h2>
        <DataTable<NominationRow>
          rows={noms}
          columns={nomCols}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No nominations logged."
        />
      </section>
    </div>
  );
}
