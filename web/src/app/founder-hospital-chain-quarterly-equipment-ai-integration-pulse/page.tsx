import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  chains_tracked: number;
  ai_modules_live: number;
  avg_adoption_pct: number;
  total_npv_inr: number;
  scale_all_count: number;
  retire_count: number;
};

type PulseRow = {
  id: string;
  pulse_quarter: string;
  chain_name: string;
  city: string;
  equipment_class: string;
  ai_module: string;
  units_eligible: number;
  units_live: number;
  adoption_pct: number;
  downtime_delta_pct: number;
  ticket_volume_delta_pct: number;
  npv_inr: number;
  scale_decision: string;
  decision_owner: string;
};

type Leader = {
  ai_module: string;
  chains_using: number;
  avg_adoption_pct: number;
  avg_downtime_delta: number;
  total_npv_inr: number;
};

type Signal = {
  id: string;
  chain_name: string;
  ai_module: string;
  signal_type: string;
  signal_count: number;
  monetary_value_inr: number;
  trend_qoq_pct: number;
  health: string;
};

type DecisionBreak = {
  scale_decision: string;
  pilot_count: number;
  total_npv_inr: number;
  avg_adoption: number;
};

type Trend = {
  chain_name: string;
  ai_module: string;
  q1_adoption_pct: number;
  q2_adoption_pct: number;
  delta_pct: number;
};

function fmtINR(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return Number(n).toFixed(2) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [ovRes, rowsRes, leadersRes, signalsRes, decRes, trendRes] = await Promise.all([
    supabase.rpc('r2783_chain_ai_pulse_overview'),
    supabase.rpc('r2783_chain_pulse_rows'),
    supabase.rpc('r2783_ai_module_leaderboard'),
    supabase.rpc('r2783_outcome_signal_rows'),
    supabase.rpc('r2783_decision_breakdown'),
    supabase.rpc('r2783_qoq_adoption_trend'),
  ]);

  const ov: Overview | null = (ovRes.data?.[0] as Overview) ?? null;
  const rows: PulseRow[] = (rowsRes.data as PulseRow[]) ?? [];
  const leaders: Leader[] = (leadersRes.data as Leader[]) ?? [];
  const signals: Signal[] = (signalsRes.data as Signal[]) ?? [];
  const decisions: DecisionBreak[] = (decRes.data as DecisionBreak[]) ?? [];
  const trends: Trend[] = (trendRes.data as Trend[]) ?? [];

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      <header>
        <h1 className="text-2xl font-bold tracking-tight">
          Hospital Chain Quarterly Equipment AI Integration Pulse
        </h1>
        <p className="text-sm text-slate-600 mt-1">
          chain × equipment × AI module × adoption × outcome × scale decision · 2026-Q2
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
        <KPI label="Chains tracked" value={ov ? String(ov.chains_tracked) : '—'} />
        <KPI label="AI modules live" value={ov ? String(ov.ai_modules_live) : '—'} />
        <KPI label="Avg adoption" value={ov ? fmtPct(ov.avg_adoption_pct) : '—'} />
        <KPI label="Total NPV" value={ov ? fmtINR(ov.total_npv_inr) : '—'} />
        <KPI label="Scale-all pilots" value={ov ? String(ov.scale_all_count) : '—'} />
        <KPI label="Retire calls" value={ov ? String(ov.retire_count) : '—'} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Chain pulse rows</h2>
        <p className="text-sm text-slate-600">
          One row per chain × equipment-class × AI-module. Adoption &gt;= 60% with NPV &gt; 0 is scale-ready.
        </p>
        <DataTable
          rows={rows}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: PulseRow) => r.chain_name },
            { key: 'city', header: 'City', render: (r: PulseRow) => r.city },
            { key: 'equipment_class', header: 'Equipment', render: (r: PulseRow) => r.equipment_class },
            { key: 'ai_module', header: 'AI module', render: (r: PulseRow) => r.ai_module },
            { key: 'adoption', header: 'Adoption', render: (r: PulseRow) => `${r.units_live}/${r.units_eligible} (${fmtPct(r.adoption_pct)})` },
            { key: 'downtime', header: 'Downtime delta', render: (r: PulseRow) => fmtPct(r.downtime_delta_pct) },
            { key: 'tickets', header: 'Ticket delta', render: (r: PulseRow) => fmtPct(r.ticket_volume_delta_pct) },
            { key: 'npv', header: 'NPV', render: (r: PulseRow) => fmtINR(r.npv_inr) },
            { key: 'decision', header: 'Decision', render: (r: PulseRow) => r.scale_decision },
            { key: 'owner', header: 'Owner', render: (r: PulseRow) => r.decision_owner },
          ]}
          emptyMessage="No data"
          rowKey={(r: PulseRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">AI module leaderboard</h2>
        <DataTable
          rows={leaders}
          columns={[
            { key: 'mod', header: 'AI module', render: (r: Leader) => r.ai_module },
            { key: 'chains', header: 'Chains using', render: (r: Leader) => String(r.chains_using) },
            { key: 'adopt', header: 'Avg adoption', render: (r: Leader) => fmtPct(r.avg_adoption_pct) },
            { key: 'down', header: 'Avg downtime delta', render: (r: Leader) => fmtPct(r.avg_downtime_delta) },
            { key: 'npv', header: 'Total NPV', render: (r: Leader) => fmtINR(r.total_npv_inr) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Leader, i: number) => `${r.ai_module}-${i}`}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Outcome signals</h2>
        <p className="text-sm text-slate-600">
          Hard outcome counts & rupee value attributed to the AI module this quarter.
        </p>
        <DataTable
          rows={signals}
          columns={[
            { key: 'chain', header: 'Chain', render: (r: Signal) => r.chain_name },
            { key: 'mod', header: 'AI module', render: (r: Signal) => r.ai_module },
            { key: 'type', header: 'Signal', render: (r: Signal) => r.signal_type },
            { key: 'count', header: 'Count', render: (r: Signal) => String(r.signal_count) },
            { key: 'value', header: 'Value', render: (r: Signal) => fmtINR(r.monetary_value_inr) },
            { key: 'trend', header: 'QoQ', render: (r: Signal) => fmtPct(r.trend_qoq_pct) },
            { key: 'health', header: 'Health', render: (r: Signal) => r.health },
          ]}
          emptyMessage="No data"
          rowKey={(r: Signal, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Decision breakdown</h2>
        <DataTable
          rows={decisions}
          columns={[
            { key: 'dec', header: 'Decision', render: (r: DecisionBreak) => r.scale_decision },
            { key: 'count', header: 'Pilots', render: (r: DecisionBreak) => String(r.pilot_count) },
            { key: 'npv', header: 'Total NPV', render: (r: DecisionBreak) => fmtINR(r.total_npv_inr) },
            { key: 'adopt', header: 'Avg adoption', render: (r: DecisionBreak) => fmtPct(r.avg_adoption) },
          ]}
          emptyMessage="No data"
          rowKey={(r: DecisionBreak, i: number) => `${r.scale_decision}-${i}`}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">QoQ adoption trend</h2>
        <p className="text-sm text-slate-600">
          Delta &gt;= 20pts means it&apos;s catching fire. Delta &lt;= 0 means a stall — investigate before next quarter.
        </p>
        <DataTable
          rows={trends}
          columns={[
            { key: 'chain', header: 'Chain', render: (r: Trend) => r.chain_name },
            { key: 'mod', header: 'AI module', render: (r: Trend) => r.ai_module },
            { key: 'q1', header: 'Q1 adoption', render: (r: Trend) => fmtPct(r.q1_adoption_pct) },
            { key: 'q2', header: 'Q2 adoption', render: (r: Trend) => fmtPct(r.q2_adoption_pct) },
            { key: 'delta', header: 'Delta (pts)', render: (r: Trend) => Number(r.delta_pct).toFixed(2) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Trend, i: number) => `${r.chain_name}-${r.ai_module}-${i}`}
        />
      </section>
    </div>
  );
}

function KPI({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-slate-200 bg-white p-4">
      <div className="text-xs uppercase tracking-wide text-slate-500">{label}</div>
      <div className="mt-1 text-xl font-semibold text-slate-900">{value}</div>
    </div>
  );
}
