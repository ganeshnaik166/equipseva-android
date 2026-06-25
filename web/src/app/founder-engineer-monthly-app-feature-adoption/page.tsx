import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_uses: number;
  total_minutes_saved: number;
  active_features: number;
  active_engineers: number;
  avg_feedback: number;
  double_down_count: number;
  sunset_candidate_count: number;
};

type FeatureRollup = {
  feature_key: string;
  feature_label: string;
  total_uses: number;
  total_minutes_saved: number;
  avg_feedback: number;
  user_count: number;
  verdict: string;
};

type EngineerRollup = {
  engineer_name: string;
  engineer_tier: string;
  features_used: number;
  total_uses: number;
  total_minutes_saved: number;
  avg_feedback: number;
};

type RecentRow = {
  engineer_name: string;
  feature_label: string;
  use_count: number;
  minutes_saved: number;
  feedback_score: number;
  last_used_at: string;
  notes: string | null;
};

type VerdictRow = {
  verdict: string;
  feature_count: number;
  avg_adoption_pct: number;
  total_power_users: number;
};

type LowAdoptionRow = {
  feature_label: string;
  adoption_pct: number;
  power_user_count: number;
  verdict: string;
  rationale: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, featuresRes, engineersRes, recentRes, verdictsRes, lowRes] = await Promise.all([
    supabase.rpc('founder_r2738_kpis'),
    supabase.rpc('founder_r2738_feature_rollup'),
    supabase.rpc('founder_r2738_engineer_rollup'),
    supabase.rpc('founder_r2738_recent_usage', { p_limit: 20 }),
    supabase.rpc('founder_r2738_verdict_breakdown'),
    supabase.rpc('founder_r2738_low_adoption'),
  ]);

  const kpis: Kpis = (kpisRes.data?.[0] as Kpis) ?? {
    total_uses: 0,
    total_minutes_saved: 0,
    active_features: 0,
    active_engineers: 0,
    avg_feedback: 0,
    double_down_count: 0,
    sunset_candidate_count: 0,
  };
  const features: FeatureRollup[] = (featuresRes.data as FeatureRollup[]) ?? [];
  const engineers: EngineerRollup[] = (engineersRes.data as EngineerRollup[]) ?? [];
  const recent: RecentRow[] = (recentRes.data as RecentRow[]) ?? [];
  const verdicts: VerdictRow[] = (verdictsRes.data as VerdictRow[]) ?? [];
  const low: LowAdoptionRow[] = (lowRes.data as LowAdoptionRow[]) ?? [];

  const hours = (mins: number) => (mins / 60).toFixed(1);

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-semibold">Engineer Monthly App Feature Adoption</h1>
        <p className="text-sm text-gray-600">
          Engineer x feature x use count x time saved x feedback x adoption verdict. Drives the keep
          vs. iterate vs. sunset call.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Card label="Total Uses (mo)" value={String(kpis.total_uses)} />
        <Card label="Hours Saved" value={hours(kpis.total_minutes_saved)} />
        <Card label="Active Features" value={String(kpis.active_features)} />
        <Card label="Active Engineers" value={String(kpis.active_engineers)} />
        <Card label="Avg Feedback" value={`${kpis.avg_feedback} / 5`} />
        <Card label="Double-Down" value={String(kpis.double_down_count)} />
        <Card label="Iterate / Sunset" value={String(kpis.sunset_candidate_count)} />
        <Card label="Round" value="r2738" />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Feature rollup (sorted by minutes saved)</h2>
        <DataTable
          rows={features}
          columns={[
            { key: 'feature_label', header: 'Feature', render: (r: FeatureRollup) => r.feature_label },
            { key: 'total_uses', header: 'Uses', render: (r: FeatureRollup) => r.total_uses },
            { key: 'total_minutes_saved', header: 'Mins saved', render: (r: FeatureRollup) => r.total_minutes_saved },
            { key: 'user_count', header: 'Engineers', render: (r: FeatureRollup) => r.user_count },
            { key: 'avg_feedback', header: 'Feedback', render: (r: FeatureRollup) => `${r.avg_feedback} / 5` },
            { key: 'verdict', header: 'Verdict', render: (r: FeatureRollup) => r.verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r: FeatureRollup, i: number) => String(r.feature_key ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer rollup</h2>
        <DataTable
          rows={engineers}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: EngineerRollup) => r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: EngineerRollup) => r.engineer_tier },
            { key: 'features_used', header: 'Features used', render: (r: EngineerRollup) => r.features_used },
            { key: 'total_uses', header: 'Uses', render: (r: EngineerRollup) => r.total_uses },
            { key: 'total_minutes_saved', header: 'Mins saved', render: (r: EngineerRollup) => r.total_minutes_saved },
            { key: 'avg_feedback', header: 'Feedback', render: (r: EngineerRollup) => `${r.avg_feedback} / 5` },
          ]}
          emptyMessage="No data"
          rowKey={(r: EngineerRollup, i: number) => String(r.engineer_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Verdict breakdown</h2>
        <DataTable
          rows={verdicts}
          columns={[
            { key: 'verdict', header: 'Verdict', render: (r: VerdictRow) => r.verdict },
            { key: 'feature_count', header: 'Features', render: (r: VerdictRow) => r.feature_count },
            { key: 'avg_adoption_pct', header: 'Avg adoption %', render: (r: VerdictRow) => `${r.avg_adoption_pct}%` },
            { key: 'total_power_users', header: 'Power users', render: (r: VerdictRow) => r.total_power_users },
          ]}
          emptyMessage="No data"
          rowKey={(r: VerdictRow, i: number) => String(r.verdict ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Low adoption (under 50%)</h2>
        <DataTable
          rows={low}
          columns={[
            { key: 'feature_label', header: 'Feature', render: (r: LowAdoptionRow) => r.feature_label },
            { key: 'adoption_pct', header: 'Adoption %', render: (r: LowAdoptionRow) => `${r.adoption_pct}%` },
            { key: 'power_user_count', header: 'Power users', render: (r: LowAdoptionRow) => r.power_user_count },
            { key: 'verdict', header: 'Verdict', render: (r: LowAdoptionRow) => r.verdict },
            { key: 'rationale', header: 'Rationale', render: (r: LowAdoptionRow) => r.rationale },
          ]}
          emptyMessage="No data"
          rowKey={(r: LowAdoptionRow, i: number) => String(r.feature_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent engineer x feature uses</h2>
        <DataTable
          rows={recent}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: RecentRow) => r.engineer_name },
            { key: 'feature_label', header: 'Feature', render: (r: RecentRow) => r.feature_label },
            { key: 'use_count', header: 'Uses', render: (r: RecentRow) => r.use_count },
            { key: 'minutes_saved', header: 'Mins saved', render: (r: RecentRow) => r.minutes_saved },
            { key: 'feedback_score', header: 'Feedback', render: (r: RecentRow) => `${r.feedback_score} / 5` },
            { key: 'last_used_at', header: 'Last used', render: (r: RecentRow) => new Date(r.last_used_at).toLocaleString() },
            { key: 'notes', header: 'Notes', render: (r: RecentRow) => r.notes ?? '' },
          ]}
          emptyMessage="No data"
          rowKey={(r: RecentRow, i: number) => String(i)}
        />
      </section>
    </div>
  );
}

function Card({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-2xl font-semibold">{value}</div>
    </div>
  );
}
