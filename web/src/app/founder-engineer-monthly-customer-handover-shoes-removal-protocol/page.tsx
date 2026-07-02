import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_visits: number;
  shoes_removed_visits: number;
  shoes_removed_pct: number;
  avg_cleanliness: number;
  complaint_visits: number;
  exemplary_engineers: number;
};

type Observation = {
  id: string;
  engineer_code: string;
  engineer_name: string;
  city: string;
  visit_date: string;
  customer_name: string;
  site_type: string;
  shoes_removed: boolean;
  shoe_cover_used: boolean;
  cleanliness_score: number;
  customer_impression: string;
  verdict: string;
  notes: string | null;
};

type Rollup = {
  id: string;
  engineer_code: string;
  engineer_name: string;
  month_label: string;
  total_visits: number;
  shoes_removed_count: number;
  shoe_cover_count: number;
  avg_cleanliness: number;
  delighted_count: number;
  complaint_count: number;
  final_verdict: string;
  bonus_rupees: number;
  penalty_rupees: number;
  coaching_recommended: boolean;
};

type VerdictRow = { verdict: string; visit_count: number; pct: number };
type SiteRow = { site_type: string; visits: number; shoes_removed_pct: number; avg_clean: number };
type CoachRow = { engineer_code: string; engineer_name: string; final_verdict: string; penalty_rupees: number; complaint_count: number };
type BonusRow = { engineer_code: string; engineer_name: string; bonus_rupees: number; penalty_rupees: number; net_rupees: number };
type CityRow = { city: string; visits: number; shoes_removed_pct: number; avg_clean: number; complaints: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, obsRes, rollupRes, verdictRes, siteRes, coachRes, bonusRes, cityRes] = await Promise.all([
    supabase.rpc('rpc_r2882_handover_kpis'),
    supabase.rpc('rpc_r2882_recent_observations'),
    supabase.rpc('rpc_r2882_monthly_rollup'),
    supabase.rpc('rpc_r2882_verdict_distribution'),
    supabase.rpc('rpc_r2882_site_type_breakdown'),
    supabase.rpc('rpc_r2882_coaching_list'),
    supabase.rpc('rpc_r2882_bonus_payouts'),
    supabase.rpc('rpc_r2882_city_heatmap'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] as Kpi) ?? {
    total_visits: 0, shoes_removed_visits: 0, shoes_removed_pct: 0,
    avg_cleanliness: 0, complaint_visits: 0, exemplary_engineers: 0,
  };
  const observations = (obsRes.data ?? []) as Observation[];
  const rollups = (rollupRes.data ?? []) as Rollup[];
  const verdicts = (verdictRes.data ?? []) as VerdictRow[];
  const sites = (siteRes.data ?? []) as SiteRow[];
  const coaching = (coachRes.data ?? []) as CoachRow[];
  const bonuses = (bonusRes.data ?? []) as BonusRow[];
  const cities = (cityRes.data ?? []) as CityRow[];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly Customer Handover — Shoes Removal Protocol</h1>
        <p className="text-sm text-gray-600">
          Round r2882 — tracks engineer cleanliness behaviour at customer sites: shoes removed, shoe cover used,
          cleanliness score 1–10, customer impression, and final verdict.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
        <KpiCard label="Total visits" value={String(kpi.total_visits)} />
        <KpiCard label="Shoes-off visits" value={String(kpi.shoes_removed_visits)} />
        <KpiCard label="Shoes-off %" value={`${kpi.shoes_removed_pct}%`} />
        <KpiCard label="Avg cleanliness" value={`${kpi.avg_cleanliness} / 10`} />
        <KpiCard label="Complaint visits" value={String(kpi.complaint_visits)} />
        <KpiCard label="Exemplary engineers" value={String(kpi.exemplary_engineers)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent visit observations</h2>
        <DataTable
          rows={observations}
          columns={[
            { key: 'visit_date', header: 'Date', render: (r: Observation) => r.visit_date },
            { key: 'engineer', header: 'Engineer', render: (r: Observation) => `${r.engineer_code} ${r.engineer_name}` },
            { key: 'city', header: 'City', render: (r: Observation) => r.city },
            { key: 'customer_name', header: 'Customer', render: (r: Observation) => r.customer_name },
            { key: 'site_type', header: 'Site', render: (r: Observation) => r.site_type },
            { key: 'shoes_removed', header: 'Shoes off', render: (r: Observation) => (r.shoes_removed ? 'yes' : 'no') },
            { key: 'shoe_cover_used', header: 'Cover', render: (r: Observation) => (r.shoe_cover_used ? 'yes' : 'no') },
            { key: 'cleanliness_score', header: 'Clean', render: (r: Observation) => `${r.cleanliness_score}/10` },
            { key: 'customer_impression', header: 'Impression', render: (r: Observation) => r.customer_impression },
            { key: 'verdict', header: 'Verdict', render: (r: Observation) => r.verdict },
            { key: 'notes', header: 'Notes', render: (r: Observation) => r.notes ?? '' },
          ]}
          emptyMessage="No data"
          rowKey={(r: Observation, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly rollup per engineer</h2>
        <DataTable
          rows={rollups}
          columns={[
            { key: 'engineer', header: 'Engineer', render: (r: Rollup) => `${r.engineer_code} ${r.engineer_name}` },
            { key: 'month_label', header: 'Month', render: (r: Rollup) => r.month_label },
            { key: 'total_visits', header: 'Visits', render: (r: Rollup) => String(r.total_visits) },
            { key: 'shoes_removed_count', header: 'Shoes off', render: (r: Rollup) => String(r.shoes_removed_count) },
            { key: 'shoe_cover_count', header: 'Covers', render: (r: Rollup) => String(r.shoe_cover_count) },
            { key: 'avg_cleanliness', header: 'Avg clean', render: (r: Rollup) => `${r.avg_cleanliness} / 10` },
            { key: 'delighted_count', header: 'Delighted', render: (r: Rollup) => String(r.delighted_count) },
            { key: 'complaint_count', header: 'Complaints', render: (r: Rollup) => String(r.complaint_count) },
            { key: 'final_verdict', header: 'Verdict', render: (r: Rollup) => r.final_verdict },
            { key: 'bonus_rupees', header: 'Bonus', render: (r: Rollup) => `Rs ${r.bonus_rupees}` },
            { key: 'penalty_rupees', header: 'Penalty', render: (r: Rollup) => `Rs ${r.penalty_rupees}` },
            { key: 'coaching_recommended', header: 'Coaching', render: (r: Rollup) => (r.coaching_recommended ? 'yes' : 'no') },
          ]}
          emptyMessage="No data"
          rowKey={(r: Rollup, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Verdict distribution</h2>
          <DataTable
            rows={verdicts}
            columns={[
              { key: 'verdict', header: 'Verdict', render: (r: VerdictRow) => r.verdict },
              { key: 'visit_count', header: 'Visits', render: (r: VerdictRow) => String(r.visit_count) },
              { key: 'pct', header: 'Share %', render: (r: VerdictRow) => `${r.pct}%` },
            ]}
            emptyMessage="No data"
            rowKey={(r: VerdictRow, i: number) => String(r.verdict ?? i)}
          />
        </div>

        <div>
          <h2 className="text-lg font-semibold mb-2">Site-type breakdown</h2>
          <DataTable
            rows={sites}
            columns={[
              { key: 'site_type', header: 'Site', render: (r: SiteRow) => r.site_type },
              { key: 'visits', header: 'Visits', render: (r: SiteRow) => String(r.visits) },
              { key: 'shoes_removed_pct', header: 'Shoes off %', render: (r: SiteRow) => `${r.shoes_removed_pct}%` },
              { key: 'avg_clean', header: 'Avg clean', render: (r: SiteRow) => `${r.avg_clean} / 10` },
            ]}
            emptyMessage="No data"
            rowKey={(r: SiteRow, i: number) => String(r.site_type ?? i)}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Coaching shortlist (penalty & complaints)</h2>
        <DataTable
          rows={coaching}
          columns={[
            { key: 'engineer', header: 'Engineer', render: (r: CoachRow) => `${r.engineer_code} ${r.engineer_name}` },
            { key: 'final_verdict', header: 'Verdict', render: (r: CoachRow) => r.final_verdict },
            { key: 'penalty_rupees', header: 'Penalty', render: (r: CoachRow) => `Rs ${r.penalty_rupees}` },
            { key: 'complaint_count', header: 'Complaints', render: (r: CoachRow) => String(r.complaint_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r: CoachRow, i: number) => String(r.engineer_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Bonus & penalty payouts</h2>
        <DataTable
          rows={bonuses}
          columns={[
            { key: 'engineer', header: 'Engineer', render: (r: BonusRow) => `${r.engineer_code} ${r.engineer_name}` },
            { key: 'bonus_rupees', header: 'Bonus', render: (r: BonusRow) => `Rs ${r.bonus_rupees}` },
            { key: 'penalty_rupees', header: 'Penalty', render: (r: BonusRow) => `Rs ${r.penalty_rupees}` },
            { key: 'net_rupees', header: 'Net', render: (r: BonusRow) => `Rs ${r.net_rupees}` },
          ]}
          emptyMessage="No data"
          rowKey={(r: BonusRow, i: number) => String(r.engineer_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">City heatmap</h2>
        <DataTable
          rows={cities}
          columns={[
            { key: 'city', header: 'City', render: (r: CityRow) => r.city },
            { key: 'visits', header: 'Visits', render: (r: CityRow) => String(r.visits) },
            { key: 'shoes_removed_pct', header: 'Shoes off %', render: (r: CityRow) => `${r.shoes_removed_pct}%` },
            { key: 'avg_clean', header: 'Avg clean', render: (r: CityRow) => `${r.avg_clean} / 10` },
            { key: 'complaints', header: 'Complaints', render: (r: CityRow) => String(r.complaints) },
          ]}
          emptyMessage="No data"
          rowKey={(r: CityRow, i: number) => String(r.city ?? i)}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-xl font-semibold">{value}</div>
    </div>
  );
}
