import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_recommendations: number;
  proposed_count: number;
  accepted_count: number;
  in_progress_count: number;
  dismissed_count: number;
  engineers_with_recs: number;
  avg_fit_score: number;
  total_revenue_uplift_rupees: number;
};

type TopRow = {
  recommendation_id: string;
  engineer_email: string;
  engineer_name: string;
  specialty_label: string;
  recommendation_kind: string;
  priority_rank: number;
  fit_score: number;
  jobs_completed_count: number;
  success_rate_pct: number;
  market_demand_score: number;
  estimated_revenue_uplift_rupees: number;
  status: string;
  generated_at: string;
};

type MixRow = {
  specialty_label: string;
  recommendation_kind: string;
  rec_count: number;
  avg_fit_score: number;
  total_uplift_rupees: number;
};

type DecisionRow = {
  decision_id: string;
  engineer_email: string;
  specialty_label: string;
  decision: string;
  decided_by_email: string;
  decided_at: string;
  decision_note: string | null;
};

type FunnelRow = {
  status: string;
  rec_count: number;
  pct_share: number;
};

function rupees(n: number | null | undefined): string {
  if (!n) return '₹0';
  return '₹' + Math.round(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [ovRes, topRes, mixRes, decRes, funnelRes] = await Promise.all([
    supabase.rpc('founder_engineer_specialty_overview_r2330'),
    supabase.rpc('founder_engineer_specialty_top_r2330', { p_limit: 50 }),
    supabase.rpc('founder_engineer_specialty_mix_r2330'),
    supabase.rpc('founder_engineer_specialty_recent_decisions_r2330', { p_limit: 30 }),
    supabase.rpc('founder_engineer_specialty_funnel_r2330'),
  ]);

  const ov: Overview | null = (ovRes.data?.[0] as Overview) ?? null;
  const top: TopRow[] = (topRes.data as TopRow[]) ?? [];
  const mix: MixRow[] = (mixRes.data as MixRow[]) ?? [];
  const decisions: DecisionRow[] = (decRes.data as DecisionRow[]) ?? [];
  const funnel: FunnelRow[] = (funnelRes.data as FunnelRow[]) ?? [];

  const topCols: Column<TopRow>[] = [
    { key: 'priority_rank', header: 'Rank', render: (r: TopRow) => <span className="font-mono">#{r.priority_rank}</span> },
    { key: 'engineer_name', header: 'Engineer', render: (r: TopRow) => (
      <div>
        <div className="font-medium">{r.engineer_name}</div>
        <div className="text-xs text-gray-500">{r.engineer_email}</div>
      </div>
    ) },
    { key: 'specialty_label', header: 'Specialty', render: (r: TopRow) => r.specialty_label },
    { key: 'recommendation_kind', header: 'Kind', render: (r: TopRow) => (
      <span className="inline-block px-2 py-0.5 rounded text-xs bg-indigo-100 text-indigo-800">{r.recommendation_kind}</span>
    ) },
    { key: 'fit_score', header: 'Fit', render: (r: TopRow) => <span className="font-mono">{Number(r.fit_score).toFixed(1)}</span> },
    { key: 'jobs_completed_count', header: 'Jobs', render: (r: TopRow) => r.jobs_completed_count },
    { key: 'success_rate_pct', header: 'Success %', render: (r: TopRow) => `${Number(r.success_rate_pct).toFixed(1)}%` },
    { key: 'market_demand_score', header: 'Demand', render: (r: TopRow) => Number(r.market_demand_score).toFixed(1) },
    { key: 'estimated_revenue_uplift_rupees', header: 'Uplift', render: (r: TopRow) => rupees(r.estimated_revenue_uplift_rupees) },
    { key: 'status', header: 'Status', render: (r: TopRow) => (
      <span className={`inline-block px-2 py-0.5 rounded text-xs ${
        r.status === 'accepted' ? 'bg-green-100 text-green-800' :
        r.status === 'in_progress' ? 'bg-blue-100 text-blue-800' :
        r.status === 'dismissed' ? 'bg-gray-100 text-gray-700' :
        r.status === 'completed' ? 'bg-emerald-100 text-emerald-800' :
        'bg-yellow-100 text-yellow-800'
      }`}>{r.status}</span>
    ) },
  ];

  const mixCols: Column<MixRow>[] = [
    { key: 'specialty_label', header: 'Specialty', render: (r: MixRow) => r.specialty_label },
    { key: 'recommendation_kind', header: 'Kind', render: (r: MixRow) => r.recommendation_kind },
    { key: 'rec_count', header: 'Count', render: (r: MixRow) => r.rec_count },
    { key: 'avg_fit_score', header: 'Avg Fit', render: (r: MixRow) => Number(r.avg_fit_score).toFixed(2) },
    { key: 'total_uplift_rupees', header: 'Total Uplift', render: (r: MixRow) => rupees(r.total_uplift_rupees) },
  ];

  const decCols: Column<DecisionRow>[] = [
    { key: 'decided_at', header: 'When', render: (r: DecisionRow) => new Date(r.decided_at).toLocaleString('en-IN') },
    { key: 'engineer_email', header: 'Engineer', render: (r: DecisionRow) => r.engineer_email },
    { key: 'specialty_label', header: 'Specialty', render: (r: DecisionRow) => r.specialty_label },
    { key: 'decision', header: 'Decision', render: (r: DecisionRow) => (
      <span className="inline-block px-2 py-0.5 rounded text-xs bg-purple-100 text-purple-800">{r.decision}</span>
    ) },
    { key: 'decided_by_email', header: 'By', render: (r: DecisionRow) => r.decided_by_email },
    { key: 'decision_note', header: 'Note', render: (r: DecisionRow) => r.decision_note ?? '—' },
  ];

  const funnelCols: Column<FunnelRow>[] = [
    { key: 'status', header: 'Status', render: (r: FunnelRow) => r.status },
    { key: 'rec_count', header: 'Count', render: (r: FunnelRow) => r.rec_count },
    { key: 'pct_share', header: 'Share %', render: (r: FunnelRow) => `${Number(r.pct_share).toFixed(1)}%` },
  ];

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-8">
      <div>
        <h1 className="text-2xl font-bold">Engineer Specialty-Deepening Engine</h1>
        <p className="text-sm text-gray-600 mt-1">
          Auto-recommendations on which specialty each engineer should deepen next, based on past jobs, fit score & market demand.
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs text-gray-500 uppercase">Total Recs</div>
          <div className="text-2xl font-bold mt-1">{ov?.total_recommendations ?? 0}</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs text-gray-500 uppercase">Proposed</div>
          <div className="text-2xl font-bold mt-1 text-yellow-700">{ov?.proposed_count ?? 0}</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs text-gray-500 uppercase">Accepted</div>
          <div className="text-2xl font-bold mt-1 text-green-700">{ov?.accepted_count ?? 0}</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs text-gray-500 uppercase">In Progress</div>
          <div className="text-2xl font-bold mt-1 text-blue-700">{ov?.in_progress_count ?? 0}</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs text-gray-500 uppercase">Dismissed</div>
          <div className="text-2xl font-bold mt-1 text-gray-700">{ov?.dismissed_count ?? 0}</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs text-gray-500 uppercase">Engineers</div>
          <div className="text-2xl font-bold mt-1">{ov?.engineers_with_recs ?? 0}</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs text-gray-500 uppercase">Avg Fit</div>
          <div className="text-2xl font-bold mt-1">{ov ? Number(ov.avg_fit_score).toFixed(1) : '0.0'}</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs text-gray-500 uppercase">Pipeline Uplift</div>
          <div className="text-2xl font-bold mt-1">{rupees(ov?.total_revenue_uplift_rupees)}</div>
        </div>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-3">Top recommendations (ranked)</h2>
        <DataTable
          rows={top}
          columns={topCols}
          rowKey={(r: TopRow) => r.recommendation_id}
          emptyMessage="No recommendations yet — engine will populate after next nightly run."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Specialty mix breakdown</h2>
        <DataTable
          rows={mix}
          columns={mixCols}
          rowKey={(r: MixRow) => `${r.specialty_label}-${r.recommendation_kind}`}
          emptyMessage="No specialty mix data yet."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Status funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          rowKey={(r: FunnelRow) => r.status}
          emptyMessage="Funnel empty."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent decisions</h2>
        <DataTable
          rows={decisions}
          columns={decCols}
          rowKey={(r: DecisionRow) => r.decision_id}
          emptyMessage="No decisions logged yet."
        />
      </section>
    </div>
  );
}
