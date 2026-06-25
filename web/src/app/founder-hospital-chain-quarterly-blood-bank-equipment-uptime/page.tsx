import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ChainRollup = { chain_name: string; fridges: number; avg_uptime: number; total_downtime_min: number; red_count: number; units_at_risk: number };
type RedFridge = { chain_name: string; blood_bank_name: string; refrigerator_tag: string; uptime_pct: number; downtime_minutes: number; units_at_risk: number; alarm_count: number };
type InterventionOutcome = { intervention_kind: string; n: number; resolved_count: number; improved_count: number; avg_delta: number; total_cost: number };
type KPI = { total_fridges: number; avg_uptime: number; red_count: number; total_units_at_risk: number; total_intervention_cost: number; resolved_pct: number };
type WorstRow = { refrigerator_tag: string; chain_name: string; blood_bank_name: string; downtime_minutes: number; alarm_count: number; temperature_excursions: number };
type RecentRow = { refrigerator_tag: string; intervention_kind: string; intervened_on: string; cost_rupees: number; outcome: string; uptime_delta_pct: number; engineer_name: string };
type Scorecard = { chain_name: string; green_count: number; amber_count: number; red_count: number; sla_score: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [rollupRes, redRes, outcomesRes, kpiRes, worstRes, recentRes, scorecardRes] = await Promise.all([
    supabase.rpc('r2791_chain_uptime_rollup'),
    supabase.rpc('r2791_red_fridges'),
    supabase.rpc('r2791_intervention_outcomes'),
    supabase.rpc('r2791_kpi_summary'),
    supabase.rpc('r2791_worst_downtime'),
    supabase.rpc('r2791_recent_interventions'),
    supabase.rpc('r2791_chain_sla_scorecard'),
  ]);

  const rollup = (rollupRes.data ?? []) as ChainRollup[];
  const red = (redRes.data ?? []) as RedFridge[];
  const outcomes = (outcomesRes.data ?? []) as InterventionOutcome[];
  const kpi = ((kpiRes.data ?? [])[0] ?? null) as KPI | null;
  const worst = (worstRes.data ?? []) as WorstRow[];
  const recent = (recentRes.data ?? []) as RecentRow[];
  const scorecard = (scorecardRes.data ?? []) as Scorecard[];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Blood Bank Equipment Uptime</h1>
        <p className="text-sm text-gray-600">Chain × blood bank × refrigerator × alarm × downtime × intervention × outcome — Q2-2026</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <div className="rounded border p-3"><div className="text-xs text-gray-500">Fridges tracked</div><div className="text-xl font-semibold">{kpi?.total_fridges ?? 0}</div></div>
        <div className="rounded border p-3"><div className="text-xs text-gray-500">Avg uptime %</div><div className="text-xl font-semibold">{kpi?.avg_uptime ?? 0}</div></div>
        <div className="rounded border p-3"><div className="text-xs text-gray-500">Red SLA fridges</div><div className="text-xl font-semibold text-red-600">{kpi?.red_count ?? 0}</div></div>
        <div className="rounded border p-3"><div className="text-xs text-gray-500">Units at risk</div><div className="text-xl font-semibold">{kpi?.total_units_at_risk ?? 0}</div></div>
        <div className="rounded border p-3"><div className="text-xs text-gray-500">Intervention spend</div><div className="text-xl font-semibold">₹{(kpi?.total_intervention_cost ?? 0).toLocaleString('en-IN')}</div></div>
        <div className="rounded border p-3"><div className="text-xs text-gray-500">Resolved %</div><div className="text-xl font-semibold">{kpi?.resolved_pct ?? 0}%</div></div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain uptime rollup</h2>
        <DataTable
          rows={rollup}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ChainRollup) => r.chain_name },
            { key: 'fridges', header: 'Fridges', render: (r: ChainRollup) => r.fridges },
            { key: 'avg_uptime', header: 'Avg uptime %', render: (r: ChainRollup) => r.avg_uptime },
            { key: 'total_downtime_min', header: 'Downtime (min)', render: (r: ChainRollup) => r.total_downtime_min },
            { key: 'red_count', header: 'Red', render: (r: ChainRollup) => r.red_count },
            { key: 'units_at_risk', header: 'Units at risk', render: (r: ChainRollup) => r.units_at_risk },
          ]}
          emptyMessage="No data"
          rowKey={(r: ChainRollup, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Red-status fridges (uptime &lt; 98%)</h2>
        <DataTable
          rows={red}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: RedFridge) => r.chain_name },
            { key: 'blood_bank_name', header: 'Blood bank', render: (r: RedFridge) => r.blood_bank_name },
            { key: 'refrigerator_tag', header: 'Fridge tag', render: (r: RedFridge) => r.refrigerator_tag },
            { key: 'uptime_pct', header: 'Uptime %', render: (r: RedFridge) => r.uptime_pct },
            { key: 'downtime_minutes', header: 'Downtime (min)', render: (r: RedFridge) => r.downtime_minutes },
            { key: 'alarm_count', header: 'Alarms', render: (r: RedFridge) => r.alarm_count },
            { key: 'units_at_risk', header: 'Units at risk', render: (r: RedFridge) => r.units_at_risk },
          ]}
          emptyMessage="No data"
          rowKey={(r: RedFridge, i: number) => String(r.refrigerator_tag ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Intervention outcomes</h2>
        <DataTable
          rows={outcomes}
          columns={[
            { key: 'intervention_kind', header: 'Intervention', render: (r: InterventionOutcome) => r.intervention_kind },
            { key: 'n', header: 'Count', render: (r: InterventionOutcome) => r.n },
            { key: 'resolved_count', header: 'Resolved', render: (r: InterventionOutcome) => r.resolved_count },
            { key: 'improved_count', header: 'Improved', render: (r: InterventionOutcome) => r.improved_count },
            { key: 'avg_delta', header: 'Avg delta %', render: (r: InterventionOutcome) => r.avg_delta },
            { key: 'total_cost', header: 'Total cost', render: (r: InterventionOutcome) => `₹${(r.total_cost ?? 0).toLocaleString('en-IN')}` },
          ]}
          emptyMessage="No data"
          rowKey={(r: InterventionOutcome, i: number) => String(r.intervention_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Worst downtime fridges</h2>
        <DataTable
          rows={worst}
          columns={[
            { key: 'refrigerator_tag', header: 'Fridge tag', render: (r: WorstRow) => r.refrigerator_tag },
            { key: 'chain_name', header: 'Chain', render: (r: WorstRow) => r.chain_name },
            { key: 'blood_bank_name', header: 'Blood bank', render: (r: WorstRow) => r.blood_bank_name },
            { key: 'downtime_minutes', header: 'Downtime (min)', render: (r: WorstRow) => r.downtime_minutes },
            { key: 'alarm_count', header: 'Alarms', render: (r: WorstRow) => r.alarm_count },
            { key: 'temperature_excursions', header: 'Temp excursions', render: (r: WorstRow) => r.temperature_excursions },
          ]}
          emptyMessage="No data"
          rowKey={(r: WorstRow, i: number) => String(r.refrigerator_tag ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain SLA scorecard</h2>
        <DataTable
          rows={scorecard}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Scorecard) => r.chain_name },
            { key: 'green_count', header: 'Green', render: (r: Scorecard) => r.green_count },
            { key: 'amber_count', header: 'Amber', render: (r: Scorecard) => r.amber_count },
            { key: 'red_count', header: 'Red', render: (r: Scorecard) => r.red_count },
            { key: 'sla_score', header: 'SLA score', render: (r: Scorecard) => `${r.sla_score}%` },
          ]}
          emptyMessage="No data"
          rowKey={(r: Scorecard, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent interventions log</h2>
        <DataTable
          rows={recent}
          columns={[
            { key: 'intervened_on', header: 'Date', render: (r: RecentRow) => r.intervened_on },
            { key: 'refrigerator_tag', header: 'Fridge tag', render: (r: RecentRow) => r.refrigerator_tag },
            { key: 'intervention_kind', header: 'Intervention', render: (r: RecentRow) => r.intervention_kind },
            { key: 'outcome', header: 'Outcome', render: (r: RecentRow) => r.outcome },
            { key: 'uptime_delta_pct', header: 'Delta %', render: (r: RecentRow) => r.uptime_delta_pct },
            { key: 'cost_rupees', header: 'Cost', render: (r: RecentRow) => `₹${(r.cost_rupees ?? 0).toLocaleString('en-IN')}` },
            { key: 'engineer_name', header: 'Engineer', render: (r: RecentRow) => r.engineer_name },
          ]}
          emptyMessage="No data"
          rowKey={(r: RecentRow, i: number) => `${r.refrigerator_tag}-${r.intervened_on}-${i}`}
        />
      </section>
    </div>
  );
}
