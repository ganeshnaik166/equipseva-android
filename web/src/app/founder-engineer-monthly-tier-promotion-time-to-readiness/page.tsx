import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_engineers: number;
  ready_now: number;
  on_track: number;
  at_risk: number;
  blocked_or_stalled: number;
  avg_weeks_to_ready: number;
  recommended_for_promotion: number;
};

type RosterRow = {
  id: number;
  engineer_name: string;
  region: string;
  current_tier: string;
  target_tier: string;
  milestones_met: number;
  milestones_required: number;
  gaps_count: number;
  weeks_to_ready: number;
  verdict: string;
  promotion_recommended: boolean;
  notes: string | null;
};

type RecRow = {
  engineer_name: string;
  region: string;
  current_tier: string;
  target_tier: string;
  milestones_met: number;
  weeks_to_ready: number;
  verdict: string;
};

type VerdictRow = {
  verdict: string;
  engineers: number;
  avg_weeks_to_ready: number;
  avg_milestones_met: number;
};

type PathRow = {
  current_tier: string;
  target_tier: string;
  engineers: number;
  ready_now: number;
  avg_weeks: number;
};

type GapRow = {
  milestone_code: string;
  milestone_label: string;
  blocker_type: string;
  engineers_affected: number;
  avg_gap: number;
  avg_weeks_to_close: number;
};

type RegionRow = {
  region: string;
  engineers: number;
  ready_now: number;
  at_risk_or_blocked: number;
  avg_weeks: number;
};

type BlockedRow = {
  engineer_name: string;
  region: string;
  current_tier: string;
  target_tier: string;
  gaps_count: number;
  weeks_to_ready: number;
  verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpi, roster, recs, verdicts, paths, gaps, regions, blocked] = await Promise.all([
    supabase.rpc('founder_r2794_readiness_kpis'),
    supabase.rpc('founder_r2794_readiness_roster'),
    supabase.rpc('founder_r2794_promotion_recommendations'),
    supabase.rpc('founder_r2794_verdict_breakdown'),
    supabase.rpc('founder_r2794_tier_path_summary'),
    supabase.rpc('founder_r2794_top_gaps'),
    supabase.rpc('founder_r2794_region_readiness'),
    supabase.rpc('founder_r2794_blocked_engineers'),
  ]);

  const k: Kpi = (kpi.data?.[0] as Kpi) ?? {
    total_engineers: 0,
    ready_now: 0,
    on_track: 0,
    at_risk: 0,
    blocked_or_stalled: 0,
    avg_weeks_to_ready: 0,
    recommended_for_promotion: 0,
  };

  const rosterRows: RosterRow[] = (roster.data as RosterRow[]) ?? [];
  const recRows: RecRow[] = (recs.data as RecRow[]) ?? [];
  const verdictRows: VerdictRow[] = (verdicts.data as VerdictRow[]) ?? [];
  const pathRows: PathRow[] = (paths.data as PathRow[]) ?? [];
  const gapRows: GapRow[] = (gaps.data as GapRow[]) ?? [];
  const regionRows: RegionRow[] = (regions.data as RegionRow[]) ?? [];
  const blockedRows: BlockedRow[] = (blocked.data as BlockedRow[]) ?? [];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Engineer Tier Promotion Time-to-Readiness</h1>
        <p className="text-sm text-gray-600">
          Monthly snapshot of engineer × current × target × milestones met × gaps × weeks-to-ready × verdict. Promotion recommended when milestones met &gt;= required for 2 months running.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <KpiCard label="Total Engineers" value={String(k.total_engineers)} />
        <KpiCard label="Ready Now" value={String(k.ready_now)} />
        <KpiCard label="On Track" value={String(k.on_track)} />
        <KpiCard label="At Risk" value={String(k.at_risk)} />
        <KpiCard label="Blocked / Stalled" value={String(k.blocked_or_stalled)} />
        <KpiCard label="Avg Weeks to Ready" value={String(k.avg_weeks_to_ready ?? 0)} />
        <KpiCard label="Promotion Recommended" value={String(k.recommended_for_promotion)} />
        <KpiCard label="Snapshot" value="Jun 2026" />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Readiness Roster</h2>
        <DataTable
          rows={rosterRows}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: RosterRow) => r.engineer_name },
            { key: 'region', header: 'Region', render: (r: RosterRow) => r.region },
            { key: 'current_tier', header: 'Current', render: (r: RosterRow) => r.current_tier },
            { key: 'target_tier', header: 'Target', render: (r: RosterRow) => r.target_tier },
            { key: 'milestones', header: 'Milestones', render: (r: RosterRow) => `${r.milestones_met} / ${r.milestones_required}` },
            { key: 'gaps_count', header: 'Gaps', render: (r: RosterRow) => String(r.gaps_count) },
            { key: 'weeks_to_ready', header: 'Weeks to Ready', render: (r: RosterRow) => String(r.weeks_to_ready) },
            { key: 'verdict', header: 'Verdict', render: (r: RosterRow) => r.verdict },
            { key: 'promotion_recommended', header: 'Promote?', render: (r: RosterRow) => (r.promotion_recommended ? 'Yes' : 'No') },
            { key: 'notes', header: 'Notes', render: (r: RosterRow) => r.notes ?? '' },
          ]}
          emptyMessage="No data"
          rowKey={(r: RosterRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Promotion Recommendations</h2>
        <DataTable
          rows={recRows}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: RecRow) => r.engineer_name },
            { key: 'region', header: 'Region', render: (r: RecRow) => r.region },
            { key: 'current_tier', header: 'Current', render: (r: RecRow) => r.current_tier },
            { key: 'target_tier', header: 'Target', render: (r: RecRow) => r.target_tier },
            { key: 'milestones_met', header: 'Milestones Met', render: (r: RecRow) => String(r.milestones_met) },
            { key: 'weeks_to_ready', header: 'Weeks to Ready', render: (r: RecRow) => String(r.weeks_to_ready) },
            { key: 'verdict', header: 'Verdict', render: (r: RecRow) => r.verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r: RecRow, i: number) => `${r.engineer_name}-${i}`}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Verdict Breakdown</h2>
        <DataTable
          rows={verdictRows}
          columns={[
            { key: 'verdict', header: 'Verdict', render: (r: VerdictRow) => r.verdict },
            { key: 'engineers', header: 'Engineers', render: (r: VerdictRow) => String(r.engineers) },
            { key: 'avg_weeks_to_ready', header: 'Avg Weeks to Ready', render: (r: VerdictRow) => String(r.avg_weeks_to_ready) },
            { key: 'avg_milestones_met', header: 'Avg Milestones Met', render: (r: VerdictRow) => String(r.avg_milestones_met) },
          ]}
          emptyMessage="No data"
          rowKey={(r: VerdictRow, i: number) => `${r.verdict}-${i}`}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Tier Path Summary</h2>
        <DataTable
          rows={pathRows}
          columns={[
            { key: 'path', header: 'Path', render: (r: PathRow) => `${r.current_tier} -> ${r.target_tier}` },
            { key: 'engineers', header: 'Engineers', render: (r: PathRow) => String(r.engineers) },
            { key: 'ready_now', header: 'Ready Now', render: (r: PathRow) => String(r.ready_now) },
            { key: 'avg_weeks', header: 'Avg Weeks', render: (r: PathRow) => String(r.avg_weeks) },
          ]}
          emptyMessage="No data"
          rowKey={(r: PathRow, i: number) => `${r.current_tier}-${r.target_tier}-${i}`}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Milestone Gaps</h2>
        <DataTable
          rows={gapRows}
          columns={[
            { key: 'milestone_label', header: 'Milestone', render: (r: GapRow) => r.milestone_label },
            { key: 'blocker_type', header: 'Blocker', render: (r: GapRow) => r.blocker_type },
            { key: 'engineers_affected', header: 'Engineers', render: (r: GapRow) => String(r.engineers_affected) },
            { key: 'avg_gap', header: 'Avg Gap', render: (r: GapRow) => String(r.avg_gap) },
            { key: 'avg_weeks_to_close', header: 'Avg Weeks to Close', render: (r: GapRow) => String(r.avg_weeks_to_close) },
          ]}
          emptyMessage="No data"
          rowKey={(r: GapRow, i: number) => `${r.milestone_code}-${i}`}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Region Readiness</h2>
        <DataTable
          rows={regionRows}
          columns={[
            { key: 'region', header: 'Region', render: (r: RegionRow) => r.region },
            { key: 'engineers', header: 'Engineers', render: (r: RegionRow) => String(r.engineers) },
            { key: 'ready_now', header: 'Ready Now', render: (r: RegionRow) => String(r.ready_now) },
            { key: 'at_risk_or_blocked', header: 'At Risk / Blocked', render: (r: RegionRow) => String(r.at_risk_or_blocked) },
            { key: 'avg_weeks', header: 'Avg Weeks', render: (r: RegionRow) => String(r.avg_weeks) },
          ]}
          emptyMessage="No data"
          rowKey={(r: RegionRow, i: number) => `${r.region}-${i}`}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Blocked & At-Risk Engineers</h2>
        <DataTable
          rows={blockedRows}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: BlockedRow) => r.engineer_name },
            { key: 'region', header: 'Region', render: (r: BlockedRow) => r.region },
            { key: 'current_tier', header: 'Current', render: (r: BlockedRow) => r.current_tier },
            { key: 'target_tier', header: 'Target', render: (r: BlockedRow) => r.target_tier },
            { key: 'gaps_count', header: 'Gaps', render: (r: BlockedRow) => String(r.gaps_count) },
            { key: 'weeks_to_ready', header: 'Weeks to Ready', render: (r: BlockedRow) => String(r.weeks_to_ready) },
            { key: 'verdict', header: 'Verdict', render: (r: BlockedRow) => r.verdict },
            { key: 'notes', header: 'Notes', render: (r: BlockedRow) => r.notes ?? '' },
          ]}
          emptyMessage="No data"
          rowKey={(r: BlockedRow, i: number) => `${r.engineer_name}-${i}`}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-2xl font-semibold text-gray-900">{value}</div>
    </div>
  );
}
