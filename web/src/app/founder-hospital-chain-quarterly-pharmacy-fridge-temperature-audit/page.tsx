import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_fridges: number;
  active_fridges: number;
  quarantined_fridges: number;
  total_events: number;
  total_minutes_out_of_range: number;
  total_rupees_at_risk: number;
  total_rupees_lost: number;
  total_loss_ratio_pct: number;
};

type ChainRow = {
  chain_name: string;
  fridges: number;
  audited_events: number;
  total_deviation_minutes: number;
  rupees_at_risk: number;
  rupees_lost: number;
  loss_ratio_pct: number;
};

type EventRow = {
  event_id: string;
  chain_name: string;
  facility_name: string;
  fridge_tag: string;
  quarter_label: string;
  deviation_started_at: string;
  duration_minutes: number;
  peak_celsius: number;
  trough_celsius: number;
  intervention: string;
  intervention_lag_minutes: number;
  outcome: string;
  rupees_at_risk: number;
  rupees_lost: number;
};

type InterventionRow = {
  intervention: string;
  events: number;
  avg_lag_minutes: number;
  avg_duration_minutes: number;
  rupees_lost: number;
};

type OutcomeRow = {
  outcome: string;
  events: number;
  rupees_at_risk: number;
  rupees_lost: number;
};

type CriticalityRow = {
  criticality: string;
  fridges: number;
  events: number;
  rupees_lost: number;
  pct_of_total_loss: number;
};

type WatchRow = {
  fridge_tag: string;
  chain_name: string;
  facility_name: string;
  worst_duration_minutes: number;
  worst_peak_celsius: number;
  rupees_lost: number;
  status: string;
};

function rupees(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, chainRes, eventsRes, interventionRes, outcomeRes, criticalityRes, watchRes] = await Promise.all([
    supabase.rpc('r2815_kpis'),
    supabase.rpc('r2815_chain_rollup'),
    supabase.rpc('r2815_deviation_events'),
    supabase.rpc('r2815_intervention_mix'),
    supabase.rpc('r2815_outcome_distribution'),
    supabase.rpc('r2815_criticality_risk'),
    supabase.rpc('r2815_long_duration_watchlist'),
  ]);

  const kpi: Kpi | null = (kpiRes.data?.[0] as Kpi) ?? null;
  const chains: ChainRow[] = (chainRes.data as ChainRow[]) ?? [];
  const events: EventRow[] = (eventsRes.data as EventRow[]) ?? [];
  const interventions: InterventionRow[] = (interventionRes.data as InterventionRow[]) ?? [];
  const outcomes: OutcomeRow[] = (outcomeRes.data as OutcomeRow[]) ?? [];
  const criticality: CriticalityRow[] = (criticalityRes.data as CriticalityRow[]) ?? [];
  const watchlist: WatchRow[] = (watchRes.data as WatchRow[]) ?? [];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Hospital Chain — Quarterly Pharmacy Fridge Temperature Audit</h1>
        <p className="text-sm text-slate-600">
          Round r2815. Target band 2 °C to 8 °C. Any reading &gt;8 °C or &lt;2 °C triggers a deviation event.
          Outcomes track whether stock was saved (lag &lt;= 30 min) or lost (lag &gt;= 60 min).
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs text-slate-500">Fridges audited</div>
          <div className="text-2xl font-semibold">{kpi?.total_fridges ?? 0}</div>
          <div className="text-xs text-slate-500">
            {kpi?.active_fridges ?? 0} active · {kpi?.quarantined_fridges ?? 0} quarantined
          </div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-slate-500">Deviation events</div>
          <div className="text-2xl font-semibold">{kpi?.total_events ?? 0}</div>
          <div className="text-xs text-slate-500">{kpi?.total_minutes_out_of_range ?? 0} min out of range</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-slate-500">Stock at risk</div>
          <div className="text-2xl font-semibold">{rupees(kpi?.total_rupees_at_risk)}</div>
          <div className="text-xs text-slate-500">Lost: {rupees(kpi?.total_rupees_lost)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-slate-500">Loss ratio</div>
          <div className="text-2xl font-semibold">{Number(kpi?.total_loss_ratio_pct ?? 0).toFixed(1)}%</div>
          <div className="text-xs text-slate-500">Lost / at-risk</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Chain rollup</h2>
        <DataTable
          rows={chains}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ChainRow) => r.chain_name },
            { key: 'fridges', header: 'Fridges', render: (r: ChainRow) => r.fridges },
            { key: 'audited_events', header: 'Events', render: (r: ChainRow) => r.audited_events },
            { key: 'total_deviation_minutes', header: 'Out-of-range (min)', render: (r: ChainRow) => r.total_deviation_minutes },
            { key: 'rupees_at_risk', header: 'At risk', render: (r: ChainRow) => rupees(r.rupees_at_risk) },
            { key: 'rupees_lost', header: 'Lost', render: (r: ChainRow) => rupees(r.rupees_lost) },
            { key: 'loss_ratio_pct', header: 'Loss %', render: (r: ChainRow) => Number(r.loss_ratio_pct).toFixed(1) + '%' },
          ]}
          emptyMessage="No data"
          rowKey={(r: ChainRow, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Deviation events</h2>
        <DataTable
          rows={events}
          columns={[
            { key: 'quarter_label', header: 'Quarter', render: (r: EventRow) => r.quarter_label },
            { key: 'chain_name', header: 'Chain', render: (r: EventRow) => r.chain_name },
            { key: 'facility_name', header: 'Facility', render: (r: EventRow) => r.facility_name },
            { key: 'fridge_tag', header: 'Fridge', render: (r: EventRow) => r.fridge_tag },
            { key: 'deviation_started_at', header: 'Started', render: (r: EventRow) => new Date(r.deviation_started_at).toLocaleString('en-IN') },
            { key: 'duration_minutes', header: 'Duration (min)', render: (r: EventRow) => r.duration_minutes },
            { key: 'peak_celsius', header: 'Peak °C', render: (r: EventRow) => Number(r.peak_celsius).toFixed(2) },
            { key: 'trough_celsius', header: 'Trough °C', render: (r: EventRow) => Number(r.trough_celsius).toFixed(2) },
            { key: 'intervention', header: 'Intervention', render: (r: EventRow) => r.intervention },
            { key: 'intervention_lag_minutes', header: 'Lag (min)', render: (r: EventRow) => r.intervention_lag_minutes },
            { key: 'outcome', header: 'Outcome', render: (r: EventRow) => r.outcome },
            { key: 'rupees_at_risk', header: 'At risk', render: (r: EventRow) => rupees(r.rupees_at_risk) },
            { key: 'rupees_lost', header: 'Lost', render: (r: EventRow) => rupees(r.rupees_lost) },
          ]}
          emptyMessage="No data"
          rowKey={(r: EventRow, i: number) => String(r.event_id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Intervention mix</h2>
        <p className="text-xs text-slate-500">Avg lag &lt;= 30 min usually saves stock; &gt;= 60 min trends to loss.</p>
        <DataTable
          rows={interventions}
          columns={[
            { key: 'intervention', header: 'Intervention', render: (r: InterventionRow) => r.intervention },
            { key: 'events', header: 'Events', render: (r: InterventionRow) => r.events },
            { key: 'avg_lag_minutes', header: 'Avg lag (min)', render: (r: InterventionRow) => Number(r.avg_lag_minutes).toFixed(1) },
            { key: 'avg_duration_minutes', header: 'Avg duration (min)', render: (r: InterventionRow) => Number(r.avg_duration_minutes).toFixed(1) },
            { key: 'rupees_lost', header: 'Lost', render: (r: InterventionRow) => rupees(r.rupees_lost) },
          ]}
          emptyMessage="No data"
          rowKey={(r: InterventionRow, i: number) => String(r.intervention ?? i)}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Outcome distribution</h2>
          <DataTable
            rows={outcomes}
            columns={[
              { key: 'outcome', header: 'Outcome', render: (r: OutcomeRow) => r.outcome },
              { key: 'events', header: 'Events', render: (r: OutcomeRow) => r.events },
              { key: 'rupees_at_risk', header: 'At risk', render: (r: OutcomeRow) => rupees(r.rupees_at_risk) },
              { key: 'rupees_lost', header: 'Lost', render: (r: OutcomeRow) => rupees(r.rupees_lost) },
            ]}
            emptyMessage="No data"
            rowKey={(r: OutcomeRow, i: number) => String(r.outcome ?? i)}
          />
        </div>

        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Criticality risk</h2>
          <DataTable
            rows={criticality}
            columns={[
              { key: 'criticality', header: 'Class', render: (r: CriticalityRow) => r.criticality },
              { key: 'fridges', header: 'Fridges', render: (r: CriticalityRow) => r.fridges },
              { key: 'events', header: 'Events', render: (r: CriticalityRow) => r.events },
              { key: 'rupees_lost', header: 'Lost', render: (r: CriticalityRow) => rupees(r.rupees_lost) },
              { key: 'pct_of_total_loss', header: '% of total loss', render: (r: CriticalityRow) => Number(r.pct_of_total_loss).toFixed(1) + '%' },
            ]}
            emptyMessage="No data"
            rowKey={(r: CriticalityRow, i: number) => String(r.criticality ?? i)}
          />
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Long-duration watchlist</h2>
        <p className="text-xs text-slate-500">Fridges with worst duration &gt;= 90 min get priority recalibration.</p>
        <DataTable
          rows={watchlist}
          columns={[
            { key: 'fridge_tag', header: 'Fridge', render: (r: WatchRow) => r.fridge_tag },
            { key: 'chain_name', header: 'Chain', render: (r: WatchRow) => r.chain_name },
            { key: 'facility_name', header: 'Facility', render: (r: WatchRow) => r.facility_name },
            { key: 'worst_duration_minutes', header: 'Worst duration (min)', render: (r: WatchRow) => r.worst_duration_minutes },
            { key: 'worst_peak_celsius', header: 'Worst peak °C', render: (r: WatchRow) => Number(r.worst_peak_celsius).toFixed(2) },
            { key: 'rupees_lost', header: 'Lost', render: (r: WatchRow) => rupees(r.rupees_lost) },
            { key: 'status', header: 'Status', render: (r: WatchRow) => r.status },
          ]}
          emptyMessage="No data"
          rowKey={(r: WatchRow, i: number) => String(r.fridge_tag ?? i)}
        />
      </section>
    </div>
  );
}
