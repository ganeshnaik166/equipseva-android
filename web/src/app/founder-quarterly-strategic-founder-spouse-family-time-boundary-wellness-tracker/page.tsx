import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type Summary = { quarter: string; total_boundaries: number; active_boundaries: number; avg_honor_rate: number; avg_spouse_satisfaction: number; avg_founder_stress: number };
type TopHonored = { boundary_label: string; boundary_category: string; honor_rate_pct: number; spouse_satisfaction_1_5: number; status: string };
type AtRisk = { boundary_label: string; boundary_category: string; honor_rate_pct: number; founder_stress_1_5: number; status: string; notes: string | null };
type Weekly = { checkin_week_starting: string; family_time_hours: number; work_hours: number; sleep_hours: number; mood_score_1_10: number; marriage_health_1_10: number };
type Conflict = { quarter: string; total_conflicts: number; total_resolutions: number; resolution_rate_pct: number; avg_mood: number };
type Breakdown = { checkin_type: string; checkin_count: number; avg_marriage_health: number; avg_family_hours: number };
type Wins = { checkin_week_starting: string; checkin_type: string; wins_summary: string | null; concerns_summary: string | null; next_action: string | null };
type Cat = { boundary_category: string; avg_honor_rate: number; avg_satisfaction: number; boundary_count: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [s, t, r, w, c, b, wc, cat] = await Promise.all([
    supabase.rpc('r2997_boundary_summary'),
    supabase.rpc('r2997_top_honored'),
    supabase.rpc('r2997_at_risk_boundaries'),
    supabase.rpc('r2997_weekly_wellness_trend'),
    supabase.rpc('r2997_conflict_resolution'),
    supabase.rpc('r2997_checkin_breakdown'),
    supabase.rpc('r2997_recent_wins_concerns'),
    supabase.rpc('r2997_category_leaderboard'),
  ]);

  const summary = (s.data ?? []) as Summary[];
  const top = (t.data ?? []) as TopHonored[];
  const risk = (r.data ?? []) as AtRisk[];
  const weekly = (w.data ?? []) as Weekly[];
  const conflict = (c.data ?? []) as Conflict[];
  const breakdown = (b.data ?? []) as Breakdown[];
  const wins = (wc.data ?? []) as Wins[];
  const catBoard = (cat.data ?? []) as Cat[];

  const summaryCols: Column<Summary>[] = [
    { header: 'Quarter', cell: (r) => r.quarter },
    { header: 'Total', cell: (r) => r.total_boundaries },
    { header: 'Active', cell: (r) => r.active_boundaries },
    { header: 'Avg Honor %', cell: (r) => r.avg_honor_rate },
    { header: 'Spouse Sat', cell: (r) => r.avg_spouse_satisfaction },
    { header: 'Founder Stress', cell: (r) => r.avg_founder_stress },
  ];

  const topCols: Column<TopHonored>[] = [
    { header: 'Boundary', cell: (r) => r.boundary_label },
    { header: 'Category', cell: (r) => r.boundary_category },
    { header: 'Honor %', cell: (r) => r.honor_rate_pct },
    { header: 'Spouse 1-5', cell: (r) => r.spouse_satisfaction_1_5 },
    { header: 'Status', cell: (r) => r.status },
  ];

  const riskCols: Column<AtRisk>[] = [
    { header: 'Boundary', cell: (r) => r.boundary_label },
    { header: 'Category', cell: (r) => r.boundary_category },
    { header: 'Honor %', cell: (r) => r.honor_rate_pct },
    { header: 'Stress', cell: (r) => r.founder_stress_1_5 },
    { header: 'Status', cell: (r) => r.status },
    { header: 'Notes', cell: (r) => r.notes ?? '' },
  ];

  const weeklyCols: Column<Weekly>[] = [
    { header: 'Week', cell: (r) => r.checkin_week_starting },
    { header: 'Family hrs', cell: (r) => r.family_time_hours },
    { header: 'Work hrs', cell: (r) => r.work_hours },
    { header: 'Sleep hrs', cell: (r) => r.sleep_hours },
    { header: 'Mood', cell: (r) => r.mood_score_1_10 },
    { header: 'Marriage', cell: (r) => r.marriage_health_1_10 },
  ];

  const conflictCols: Column<Conflict>[] = [
    { header: 'Quarter', cell: (r) => r.quarter },
    { header: 'Conflicts', cell: (r) => r.total_conflicts },
    { header: 'Resolutions', cell: (r) => r.total_resolutions },
    { header: 'Resolve %', cell: (r) => r.resolution_rate_pct },
    { header: 'Avg Mood', cell: (r) => r.avg_mood },
  ];

  const breakdownCols: Column<Breakdown>[] = [
    { header: 'Type', cell: (r) => r.checkin_type },
    { header: 'Count', cell: (r) => r.checkin_count },
    { header: 'Avg Marriage', cell: (r) => r.avg_marriage_health },
    { header: 'Avg Family hrs', cell: (r) => r.avg_family_hours },
  ];

  const winsCols: Column<Wins>[] = [
    { header: 'Week', cell: (r) => r.checkin_week_starting },
    { header: 'Type', cell: (r) => r.checkin_type },
    { header: 'Wins', cell: (r) => r.wins_summary ?? '' },
    { header: 'Concerns', cell: (r) => r.concerns_summary ?? '' },
    { header: 'Next', cell: (r) => r.next_action ?? '' },
  ];

  const catCols: Column<Cat>[] = [
    { header: 'Category', cell: (r) => r.boundary_category },
    { header: 'Avg Honor %', cell: (r) => r.avg_honor_rate },
    { header: 'Avg Satisfaction', cell: (r) => r.avg_satisfaction },
    { header: 'Count', cell: (r) => r.boundary_count },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder-Spouse Family-Time Boundary & Wellness Tracker</h1>
        <p className="text-sm text-gray-600">Quarterly strategic review of family-time boundaries, wellness check-ins, and marriage health metrics for the founder household.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarter Summary</h2>
        <DataTable rows={summary} columns={summaryCols} emptyMessage="No summary." rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Honored Boundaries (Q2 2026)</h2>
        <DataTable rows={top} columns={topCols} emptyMessage="No boundaries." rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">At-Risk Boundaries (honor &lt; 80%)</h2>
        <DataTable rows={risk} columns={riskCols} emptyMessage="No at-risk boundaries." rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Weekly Wellness Trend</h2>
        <DataTable rows={weekly} columns={weeklyCols} emptyMessage="No check-ins." rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Conflict Resolution</h2>
        <DataTable rows={conflict} columns={conflictCols} emptyMessage="No data." rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Check-in Type Breakdown</h2>
        <DataTable rows={breakdown} columns={breakdownCols} emptyMessage="No data." rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Wins & Concerns</h2>
        <DataTable rows={wins} columns={winsCols} emptyMessage="No wins logged." rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Category Honor Leaderboard</h2>
        <DataTable rows={catBoard} columns={catCols} emptyMessage="No categories." rowKey={(r, i) => String(i)} />
      </section>
    </div>
  );
}
