import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = {
  total_sessions: number;
  avg_clarity: number;
  avg_adoption: number;
  open_refines: number;
  followup_repair_rate: number;
  promotion_eligible_count: number;
};

type SessionRow = {
  id: string;
  engineer_name: string;
  engineer_region: string;
  customer_org: string;
  spoken_language: string;
  equipment_category: string;
  handover_minutes: number;
  clarity_score: number;
  adoption_followup_pct: number;
  refine_action: string;
  refine_status: string;
};

type LanguageRow = {
  spoken_language: string;
  session_count: number;
  avg_clarity: number;
  avg_adoption: number;
  avg_repeat_back: number;
};

type ScorecardRow = {
  id: string;
  engineer_name: string;
  primary_language: string;
  fluency_self_rated: number;
  fluency_customer_rated: number;
  sessions_count: number;
  avg_clarity_score: number;
  avg_adoption_pct: number;
  refine_actions_open: number;
  coaching_track: string;
  promotion_eligible: boolean;
};

type RefineRow = {
  refine_action: string;
  refine_status: string;
  count_sessions: number;
  avg_clarity: number;
};

type RegionRow = {
  engineer_region: string;
  session_count: number;
  avg_clarity: number;
  avg_adoption: number;
  followup_rate: number;
};

type CoachingRow = {
  coaching_track: string;
  engineer_count: number;
  avg_clarity: number;
  avg_adoption: number;
};

type MomRow = {
  engineer_name: string;
  cur_avg_clarity: number;
  prev_avg_clarity: number;
  clarity_delta: number;
  cur_sessions: number;
  prev_sessions: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, sessionsRes, languagesRes, scorecardsRes, refineRes, regionRes, coachingRes, momRes] = await Promise.all([
    supabase.rpc('founder_r2876_kpis'),
    supabase.rpc('founder_r2876_sessions'),
    supabase.rpc('founder_r2876_language_breakdown'),
    supabase.rpc('founder_r2876_scorecards'),
    supabase.rpc('founder_r2876_refine_funnel'),
    supabase.rpc('founder_r2876_region_rollup'),
    supabase.rpc('founder_r2876_coaching_distribution'),
    supabase.rpc('founder_r2876_engineer_mom'),
  ]);

  const kpis: KpiRow = (kpisRes.data?.[0] as KpiRow) ?? {
    total_sessions: 0,
    avg_clarity: 0,
    avg_adoption: 0,
    open_refines: 0,
    followup_repair_rate: 0,
    promotion_eligible_count: 0,
  };
  const sessions: SessionRow[] = (sessionsRes.data as SessionRow[]) ?? [];
  const languages: LanguageRow[] = (languagesRes.data as LanguageRow[]) ?? [];
  const scorecards: ScorecardRow[] = (scorecardsRes.data as ScorecardRow[]) ?? [];
  const refines: RefineRow[] = (refineRes.data as RefineRow[]) ?? [];
  const regions: RegionRow[] = (regionRes.data as RegionRow[]) ?? [];
  const coaching: CoachingRow[] = (coachingRes.data as CoachingRow[]) ?? [];
  const moms: MomRow[] = (momRes.data as MomRow[]) ?? [];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Bilingual Handover Effectiveness</h1>
        <p className="text-sm text-gray-600">
          Engineer x customer x spoken language: clarity, adoption, and refine actions per month.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
        <KpiCard label="Sessions" value={String(kpis.total_sessions)} />
        <KpiCard label="Avg Clarity" value={`${kpis.avg_clarity} / 5`} />
        <KpiCard label="Avg Adoption %" value={`${kpis.avg_adoption}%`} />
        <KpiCard label="Open Refines" value={String(kpis.open_refines)} />
        <KpiCard label="Followup Repair Rate" value={`${kpis.followup_repair_rate}%`} />
        <KpiCard label="Promotion Eligible" value={String(kpis.promotion_eligible_count)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Sessions this month (sorted by lowest clarity first)</h2>
        <DataTable
          rows={sessions}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: SessionRow) => r.engineer_name },
            { key: 'engineer_region', header: 'Region', render: (r: SessionRow) => r.engineer_region },
            { key: 'customer_org', header: 'Customer', render: (r: SessionRow) => r.customer_org },
            { key: 'spoken_language', header: 'Spoken Lang', render: (r: SessionRow) => r.spoken_language },
            { key: 'equipment_category', header: 'Equipment', render: (r: SessionRow) => r.equipment_category },
            { key: 'handover_minutes', header: 'Minutes', render: (r: SessionRow) => String(r.handover_minutes) },
            { key: 'clarity_score', header: 'Clarity', render: (r: SessionRow) => `${r.clarity_score} / 5` },
            { key: 'adoption_followup_pct', header: 'Adoption %', render: (r: SessionRow) => `${r.adoption_followup_pct}%` },
            { key: 'refine_action', header: 'Refine Action', render: (r: SessionRow) => r.refine_action },
            { key: 'refine_status', header: 'Status', render: (r: SessionRow) => r.refine_status },
          ]}
          emptyMessage="No data"
          rowKey={(r: SessionRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Language breakdown</h2>
        <DataTable
          rows={languages}
          columns={[
            { key: 'spoken_language', header: 'Language', render: (r: LanguageRow) => r.spoken_language },
            { key: 'session_count', header: 'Sessions', render: (r: LanguageRow) => String(r.session_count) },
            { key: 'avg_clarity', header: 'Avg Clarity', render: (r: LanguageRow) => `${r.avg_clarity} / 5` },
            { key: 'avg_adoption', header: 'Avg Adoption %', render: (r: LanguageRow) => `${r.avg_adoption}%` },
            { key: 'avg_repeat_back', header: 'Avg Repeat-Back %', render: (r: LanguageRow) => `${r.avg_repeat_back}%` },
          ]}
          emptyMessage="No data"
          rowKey={(r: LanguageRow, i: number) => `${r.spoken_language}-${i}`}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer scorecards</h2>
        <DataTable
          rows={scorecards}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: ScorecardRow) => r.engineer_name },
            { key: 'primary_language', header: 'Primary Lang', render: (r: ScorecardRow) => r.primary_language },
            { key: 'fluency_self_rated', header: 'Self Fluency', render: (r: ScorecardRow) => `${r.fluency_self_rated} / 5` },
            { key: 'fluency_customer_rated', header: 'Customer Fluency', render: (r: ScorecardRow) => `${r.fluency_customer_rated} / 5` },
            { key: 'sessions_count', header: 'Sessions', render: (r: ScorecardRow) => String(r.sessions_count) },
            { key: 'avg_clarity_score', header: 'Avg Clarity', render: (r: ScorecardRow) => `${r.avg_clarity_score} / 5` },
            { key: 'avg_adoption_pct', header: 'Avg Adoption %', render: (r: ScorecardRow) => `${r.avg_adoption_pct}%` },
            { key: 'refine_actions_open', header: 'Open Refines', render: (r: ScorecardRow) => String(r.refine_actions_open) },
            { key: 'coaching_track', header: 'Coaching', render: (r: ScorecardRow) => r.coaching_track },
            { key: 'promotion_eligible', header: 'Promotable', render: (r: ScorecardRow) => (r.promotion_eligible ? 'yes' : 'no') },
          ]}
          emptyMessage="No data"
          rowKey={(r: ScorecardRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Refine funnel</h2>
        <DataTable
          rows={refines}
          columns={[
            { key: 'refine_action', header: 'Action', render: (r: RefineRow) => r.refine_action },
            { key: 'refine_status', header: 'Status', render: (r: RefineRow) => r.refine_status },
            { key: 'count_sessions', header: 'Sessions', render: (r: RefineRow) => String(r.count_sessions) },
            { key: 'avg_clarity', header: 'Avg Clarity', render: (r: RefineRow) => `${r.avg_clarity} / 5` },
          ]}
          emptyMessage="No data"
          rowKey={(r: RefineRow, i: number) => `${r.refine_action}-${r.refine_status}-${i}`}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Region rollup</h2>
        <DataTable
          rows={regions}
          columns={[
            { key: 'engineer_region', header: 'Region', render: (r: RegionRow) => r.engineer_region },
            { key: 'session_count', header: 'Sessions', render: (r: RegionRow) => String(r.session_count) },
            { key: 'avg_clarity', header: 'Avg Clarity', render: (r: RegionRow) => `${r.avg_clarity} / 5` },
            { key: 'avg_adoption', header: 'Avg Adoption %', render: (r: RegionRow) => `${r.avg_adoption}%` },
            { key: 'followup_rate', header: 'Followup %', render: (r: RegionRow) => `${r.followup_rate}%` },
          ]}
          emptyMessage="No data"
          rowKey={(r: RegionRow, i: number) => `${r.engineer_region}-${i}`}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Coaching distribution</h2>
        <DataTable
          rows={coaching}
          columns={[
            { key: 'coaching_track', header: 'Track', render: (r: CoachingRow) => r.coaching_track },
            { key: 'engineer_count', header: 'Engineers', render: (r: CoachingRow) => String(r.engineer_count) },
            { key: 'avg_clarity', header: 'Avg Clarity', render: (r: CoachingRow) => `${r.avg_clarity} / 5` },
            { key: 'avg_adoption', header: 'Avg Adoption %', render: (r: CoachingRow) => `${r.avg_adoption}%` },
          ]}
          emptyMessage="No data"
          rowKey={(r: CoachingRow, i: number) => `${r.coaching_track}-${i}`}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer month-over-month clarity delta</h2>
        <DataTable
          rows={moms}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: MomRow) => r.engineer_name },
            { key: 'cur_avg_clarity', header: 'Current Clarity', render: (r: MomRow) => `${r.cur_avg_clarity} / 5` },
            { key: 'prev_avg_clarity', header: 'Prev Clarity', render: (r: MomRow) => `${r.prev_avg_clarity} / 5` },
            { key: 'clarity_delta', header: 'Delta', render: (r: MomRow) => String(r.clarity_delta) },
            { key: 'cur_sessions', header: 'Cur Sessions', render: (r: MomRow) => String(r.cur_sessions) },
            { key: 'prev_sessions', header: 'Prev Sessions', render: (r: MomRow) => String(r.prev_sessions) },
          ]}
          emptyMessage="No data"
          rowKey={(r: MomRow, i: number) => `${r.engineer_name}-${i}`}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="border rounded-md p-3 bg-white shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="text-xl font-semibold mt-1">{value}</div>
    </div>
  );
}
