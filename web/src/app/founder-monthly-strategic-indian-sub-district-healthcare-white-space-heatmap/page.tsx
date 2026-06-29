import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type Heatmap = { state_name: string; sub_district_name: string; white_space_score: number; priority_rank: string; estimated_tam_lakhs_inr: number; tier_classification: string };
type StateRollup = { state_name: string; sub_districts_surveyed: number; avg_white_space: number; total_tam_lakhs: number; p0_count: number };
type Tier = { tier_classification: string; sub_district_count: number; avg_amc_penetration: number; avg_white_space: number; total_tam_lakhs: number };
type Pipeline = { sub_district_name: string; state_name: string; go_live_status: string; planned_launch_date: string; expected_arr_lakhs_inr: number; payback_months: number; owner_name: string };
type StatusMix = { go_live_status: string; plan_count: number; total_capex_lakhs: number; total_expected_arr_lakhs: number; avg_payback_months: number };
type Matched = { sub_district_name: string; state_name: string; white_space_score: number; priority_rank: string; go_live_status: string; expected_arr_lakhs_inr: number };
type Unaddr = { sub_district_name: string; state_name: string; white_space_score: number; priority_rank: string; estimated_tam_lakhs_inr: number; population_thousands: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [h, s, t, p, m, mc, u] = await Promise.all([
    supabase.rpc('rpc_r2965_priority_heatmap'),
    supabase.rpc('rpc_r2965_state_rollup'),
    supabase.rpc('rpc_r2965_tier_breakdown'),
    supabase.rpc('rpc_r2965_expansion_pipeline'),
    supabase.rpc('rpc_r2965_status_mix'),
    supabase.rpc('rpc_r2965_matched_candidates'),
    supabase.rpc('rpc_r2965_unaddressed_whitespace'),
  ]);

  const heatmap = (h.data ?? []) as Heatmap[];
  const stateRoll = (s.data ?? []) as StateRollup[];
  const tier = (t.data ?? []) as Tier[];
  const pipeline = (p.data ?? []) as Pipeline[];
  const statusMix = (m.data ?? []) as StatusMix[];
  const matched = (mc.data ?? []) as Matched[];
  const unaddr = (u.data ?? []) as Unaddr[];

  const heatCols: Column<Heatmap>[] = [
    { header: 'State', accessor: (r) => r.state_name },
    { header: 'Sub-district', accessor: (r) => r.sub_district_name },
    { header: 'Score', accessor: (r) => r.white_space_score },
    { header: 'Priority', accessor: (r) => r.priority_rank },
    { header: 'TAM (L)', accessor: (r) => r.estimated_tam_lakhs_inr },
    { header: 'Tier', accessor: (r) => r.tier_classification },
  ];
  const stateCols: Column<StateRollup>[] = [
    { header: 'State', accessor: (r) => r.state_name },
    { header: 'Surveyed', accessor: (r) => r.sub_districts_surveyed },
    { header: 'Avg WS', accessor: (r) => r.avg_white_space },
    { header: 'TAM (L)', accessor: (r) => r.total_tam_lakhs },
    { header: 'P0', accessor: (r) => r.p0_count },
  ];
  const tierCols: Column<Tier>[] = [
    { header: 'Tier', accessor: (r) => r.tier_classification },
    { header: 'Count', accessor: (r) => r.sub_district_count },
    { header: 'AMC %', accessor: (r) => r.avg_amc_penetration },
    { header: 'Avg WS', accessor: (r) => r.avg_white_space },
    { header: 'TAM (L)', accessor: (r) => r.total_tam_lakhs },
  ];
  const pipeCols: Column<Pipeline>[] = [
    { header: 'Sub-district', accessor: (r) => r.sub_district_name },
    { header: 'State', accessor: (r) => r.state_name },
    { header: 'Status', accessor: (r) => r.go_live_status },
    { header: 'Launch', accessor: (r) => r.planned_launch_date },
    { header: 'ARR (L)', accessor: (r) => r.expected_arr_lakhs_inr },
    { header: 'Payback (mo)', accessor: (r) => r.payback_months },
    { header: 'Owner', accessor: (r) => r.owner_name },
  ];
  const statusCols: Column<StatusMix>[] = [
    { header: 'Status', accessor: (r) => r.go_live_status },
    { header: 'Plans', accessor: (r) => r.plan_count },
    { header: 'Capex (L)', accessor: (r) => r.total_capex_lakhs },
    { header: 'ARR (L)', accessor: (r) => r.total_expected_arr_lakhs },
    { header: 'Avg payback', accessor: (r) => r.avg_payback_months },
  ];
  const matchedCols: Column<Matched>[] = [
    { header: 'Sub-district', accessor: (r) => r.sub_district_name },
    { header: 'State', accessor: (r) => r.state_name },
    { header: 'WS Score', accessor: (r) => r.white_space_score },
    { header: 'Priority', accessor: (r) => r.priority_rank },
    { header: 'Plan Status', accessor: (r) => r.go_live_status },
    { header: 'ARR (L)', accessor: (r) => r.expected_arr_lakhs_inr },
  ];
  const unaddrCols: Column<Unaddr>[] = [
    { header: 'Sub-district', accessor: (r) => r.sub_district_name },
    { header: 'State', accessor: (r) => r.state_name },
    { header: 'WS Score', accessor: (r) => r.white_space_score },
    { header: 'Priority', accessor: (r) => r.priority_rank },
    { header: 'TAM (L)', accessor: (r) => r.estimated_tam_lakhs_inr },
    { header: 'Pop (k)', accessor: (r) => r.population_thousands },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Monthly Strategic Sub-District White-Space Heatmap</h1>
        <p className="text-sm text-gray-600">Surveyed sub-districts ranked by white-space score & TAM; matched against expansion pipeline.</p>
      </header>

      <section>
        <h2 className="font-semibold mb-2">Priority heatmap (highest white-space first)</h2>
        <DataTable rows={heatmap} columns={heatCols} emptyMessage="No survey data" rowKey={(r, i) => String((r as Heatmap).sub_district_name ?? i)} />
      </section>

      <section>
        <h2 className="font-semibold mb-2">State rollup</h2>
        <DataTable rows={stateRoll} columns={stateCols} emptyMessage="No states" rowKey={(r, i) => String((r as StateRollup).state_name ?? i)} />
      </section>

      <section>
        <h2 className="font-semibold mb-2">Tier breakdown</h2>
        <DataTable rows={tier} columns={tierCols} emptyMessage="No tiers" rowKey={(r, i) => String((r as Tier).tier_classification ?? i)} />
      </section>

      <section>
        <h2 className="font-semibold mb-2">Expansion pipeline</h2>
        <DataTable rows={pipeline} columns={pipeCols} emptyMessage="No plans" rowKey={(r, i) => String((r as Pipeline).sub_district_name ?? i)} />
      </section>

      <section>
        <h2 className="font-semibold mb-2">Pipeline status mix</h2>
        <DataTable rows={statusMix} columns={statusCols} emptyMessage="No status" rowKey={(r, i) => String((r as StatusMix).go_live_status ?? i)} />
      </section>

      <section>
        <h2 className="font-semibold mb-2">Matched: white-space & plan</h2>
        <DataTable rows={matched} columns={matchedCols} emptyMessage="No matches" rowKey={(r, i) => String((r as Matched).sub_district_name ?? i)} />
      </section>

      <section>
        <h2 className="font-semibold mb-2">Unaddressed white-space (no plan yet)</h2>
        <DataTable rows={unaddr} columns={unaddrCols} emptyMessage="All addressed" rowKey={(r, i) => String((r as Unaddr).sub_district_name ?? i)} />
      </section>
    </div>
  );
}
