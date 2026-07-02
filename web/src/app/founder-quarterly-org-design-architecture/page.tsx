import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Capacity = {
  id: string;
  quarter: string;
  function_name: string;
  headcount_current: number;
  headcount_target: number;
  bottleneck_severity: string;
  bottleneck_summary: string;
  utilization_pct: number;
  attrition_pct: number;
  cost_per_quarter_rupees: number;
  notes: string | null;
};

type Play = {
  id: string;
  quarter: string;
  function_name: string;
  play_kind: string;
  play_summary: string;
  headcount_delta: number;
  estimated_cost_rupees: number;
  expected_outcome: string;
  outcome_status: string;
  realized_outcome: string | null;
  effective_date: string;
};

type Hotspot = {
  function_name: string;
  headcount_gap: number;
  utilization_pct: number;
  attrition_pct: number;
  bottleneck_severity: string;
  cost_per_quarter_rupees: number;
};

type ByKind = {
  play_kind: string;
  total_plays: number;
  total_headcount_delta: number;
  total_cost_rupees: number;
  realized_plays: number;
};

type Outcome = {
  outcome_status: string;
  total: number;
  total_cost_rupees: number;
};

type Alignment = {
  function_name: string;
  bottleneck_severity: string;
  headcount_gap: number;
  plays_in_flight: number;
  plays_approved: number;
  has_coverage: boolean;
};

type Trajectory = {
  quarter: string;
  total_headcount: number;
  total_cost_rupees: number;
  realized_play_cost_rupees: number;
};

function rupees(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overviewRes, capacityRes, hotspotRes, playsRes, byKindRes, outcomeRes, alignmentRes, trajectoryRes] = await Promise.all([
    supabase.rpc('founder_org_capacity_overview_r2757'),
    supabase.rpc('founder_org_capacity_list_r2757'),
    supabase.rpc('founder_org_bottleneck_hotspots_r2757'),
    supabase.rpc('founder_org_plays_list_r2757'),
    supabase.rpc('founder_org_plays_by_kind_r2757'),
    supabase.rpc('founder_org_plays_outcome_summary_r2757'),
    supabase.rpc('founder_org_function_play_alignment_r2757'),
    supabase.rpc('founder_org_quarterly_cost_trajectory_r2757'),
  ]);

  const overview = (overviewRes.data?.[0] ?? {
    total_functions: 0,
    total_headcount: 0,
    total_target: 0,
    critical_functions: 0,
    severe_functions: 0,
    total_quarterly_cost_rupees: 0,
  }) as {
    total_functions: number;
    total_headcount: number;
    total_target: number;
    critical_functions: number;
    severe_functions: number;
    total_quarterly_cost_rupees: number;
  };

  const capacity = (capacityRes.data ?? []) as Capacity[];
  const hotspots = (hotspotRes.data ?? []) as Hotspot[];
  const plays = (playsRes.data ?? []) as Play[];
  const byKind = (byKindRes.data ?? []) as ByKind[];
  const outcomes = (outcomeRes.data ?? []) as Outcome[];
  const alignment = (alignmentRes.data ?? []) as Alignment[];
  const trajectory = (trajectoryRes.data ?? []) as Trajectory[];

  const gap = Number(overview.total_target) - Number(overview.total_headcount);

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Quarterly Org Design Architecture</h1>
        <p className="text-sm text-gray-600">
          Function × headcount × bottleneck × split/merge × redesign × outcome — founder-only quarterly view.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
        <KpiCard label="Functions" value={String(overview.total_functions)} />
        <KpiCard label="Headcount Now" value={String(overview.total_headcount)} />
        <KpiCard label="Headcount Target" value={String(overview.total_target)} />
        <KpiCard label="Gap" value={(gap >= 0 ? '+' : '') + String(gap)} tone={gap > 0 ? 'warn' : 'ok'} />
        <KpiCard label="Critical Bottlenecks" value={String(overview.critical_functions)} tone="bad" />
        <KpiCard label="Quarterly Cost" value={rupees(overview.total_quarterly_cost_rupees)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Function capacity (Q3-2026)</h2>
        <DataTable
          rows={capacity}
          columns={[
            { key: 'function_name', header: 'Function', render: (r: Capacity) => r.function_name },
            { key: 'headcount_current', header: 'Now', render: (r: Capacity) => r.headcount_current },
            { key: 'headcount_target', header: 'Target', render: (r: Capacity) => r.headcount_target },
            { key: 'utilization_pct', header: 'Util %', render: (r: Capacity) => Number(r.utilization_pct).toFixed(1) },
            { key: 'attrition_pct', header: 'Attrition %', render: (r: Capacity) => Number(r.attrition_pct).toFixed(1) },
            { key: 'bottleneck_severity', header: 'Severity', render: (r: Capacity) => <SeverityPill v={r.bottleneck_severity} /> },
            { key: 'bottleneck_summary', header: 'Bottleneck', render: (r: Capacity) => r.bottleneck_summary },
            { key: 'cost_per_quarter_rupees', header: 'Cost / Q', render: (r: Capacity) => rupees(r.cost_per_quarter_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Capacity, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Bottleneck hotspots (severe & critical)</h2>
        <DataTable
          rows={hotspots}
          columns={[
            { key: 'function_name', header: 'Function', render: (r: Hotspot) => r.function_name },
            { key: 'headcount_gap', header: 'Gap', render: (r: Hotspot) => r.headcount_gap },
            { key: 'utilization_pct', header: 'Util %', render: (r: Hotspot) => Number(r.utilization_pct).toFixed(1) },
            { key: 'attrition_pct', header: 'Attrition %', render: (r: Hotspot) => Number(r.attrition_pct).toFixed(1) },
            { key: 'bottleneck_severity', header: 'Severity', render: (r: Hotspot) => <SeverityPill v={r.bottleneck_severity} /> },
            { key: 'cost_per_quarter_rupees', header: 'Cost / Q', render: (r: Hotspot) => rupees(r.cost_per_quarter_rupees) },
          ]}
          emptyMessage="No hotspots"
          rowKey={(r: Hotspot, i: number) => String(r.function_name + '-' + i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Redesign plays</h2>
        <DataTable
          rows={plays}
          columns={[
            { key: 'effective_date', header: 'Effective', render: (r: Play) => r.effective_date },
            { key: 'function_name', header: 'Function', render: (r: Play) => r.function_name },
            { key: 'play_kind', header: 'Kind', render: (r: Play) => <KindPill v={r.play_kind} /> },
            { key: 'play_summary', header: 'Play', render: (r: Play) => r.play_summary },
            { key: 'headcount_delta', header: 'HC Δ', render: (r: Play) => (r.headcount_delta >= 0 ? '+' : '') + r.headcount_delta },
            { key: 'estimated_cost_rupees', header: 'Est cost', render: (r: Play) => rupees(r.estimated_cost_rupees) },
            { key: 'expected_outcome', header: 'Expected outcome', render: (r: Play) => r.expected_outcome },
            { key: 'outcome_status', header: 'Status', render: (r: Play) => <StatusPill v={r.outcome_status} /> },
            { key: 'realized_outcome', header: 'Realized', render: (r: Play) => r.realized_outcome ?? '—' },
          ]}
          emptyMessage="No plays"
          rowKey={(r: Play, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="space-y-3">
          <h2 className="text-lg font-medium">Plays by kind</h2>
          <DataTable
            rows={byKind}
            columns={[
              { key: 'play_kind', header: 'Kind', render: (r: ByKind) => <KindPill v={r.play_kind} /> },
              { key: 'total_plays', header: 'Plays', render: (r: ByKind) => r.total_plays },
              { key: 'total_headcount_delta', header: 'HC Δ', render: (r: ByKind) => (Number(r.total_headcount_delta) >= 0 ? '+' : '') + r.total_headcount_delta },
              { key: 'total_cost_rupees', header: 'Cost', render: (r: ByKind) => rupees(r.total_cost_rupees) },
              { key: 'realized_plays', header: 'Realized', render: (r: ByKind) => r.realized_plays },
            ]}
            emptyMessage="No data"
            rowKey={(r: ByKind, i: number) => String(r.play_kind + '-' + i)}
          />
        </div>

        <div className="space-y-3">
          <h2 className="text-lg font-medium">Outcome summary</h2>
          <DataTable
            rows={outcomes}
            columns={[
              { key: 'outcome_status', header: 'Status', render: (r: Outcome) => <StatusPill v={r.outcome_status} /> },
              { key: 'total', header: 'Count', render: (r: Outcome) => r.total },
              { key: 'total_cost_rupees', header: 'Cost', render: (r: Outcome) => rupees(r.total_cost_rupees) },
            ]}
            emptyMessage="No data"
            rowKey={(r: Outcome, i: number) => String(r.outcome_status + '-' + i)}
          />
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Function vs play alignment</h2>
        <p className="text-sm text-gray-600">
          Where severity is severe or critical but coverage is false — that's an unresolved bottleneck.
        </p>
        <DataTable
          rows={alignment}
          columns={[
            { key: 'function_name', header: 'Function', render: (r: Alignment) => r.function_name },
            { key: 'bottleneck_severity', header: 'Severity', render: (r: Alignment) => <SeverityPill v={r.bottleneck_severity} /> },
            { key: 'headcount_gap', header: 'Gap', render: (r: Alignment) => r.headcount_gap },
            { key: 'plays_in_flight', header: 'In flight', render: (r: Alignment) => r.plays_in_flight },
            { key: 'plays_approved', header: 'Approved', render: (r: Alignment) => r.plays_approved },
            { key: 'has_coverage', header: 'Covered', render: (r: Alignment) => r.has_coverage ? 'yes' : 'no' },
          ]}
          emptyMessage="No data"
          rowKey={(r: Alignment, i: number) => String(r.function_name + '-' + i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Quarterly cost trajectory</h2>
        <DataTable
          rows={trajectory}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r: Trajectory) => r.quarter },
            { key: 'total_headcount', header: 'Headcount', render: (r: Trajectory) => r.total_headcount },
            { key: 'total_cost_rupees', header: 'Run cost', render: (r: Trajectory) => rupees(r.total_cost_rupees) },
            { key: 'realized_play_cost_rupees', header: 'Realized play cost', render: (r: Trajectory) => rupees(r.realized_play_cost_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Trajectory, i: number) => String(r.quarter + '-' + i)}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value, tone }: { label: string; value: string; tone?: 'ok' | 'warn' | 'bad' }) {
  const toneCls =
    tone === 'bad'
      ? 'border-red-200 bg-red-50'
      : tone === 'warn'
      ? 'border-amber-200 bg-amber-50'
      : tone === 'ok'
      ? 'border-emerald-200 bg-emerald-50'
      : 'border-gray-200 bg-white';
  return (
    <div className={'rounded-lg border p-3 ' + toneCls}>
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-lg font-semibold">{value}</div>
    </div>
  );
}

function SeverityPill({ v }: { v: string }) {
  const map: Record<string, string> = {
    critical: 'bg-red-100 text-red-800',
    severe: 'bg-orange-100 text-orange-800',
    moderate: 'bg-amber-100 text-amber-800',
    minor: 'bg-blue-100 text-blue-800',
    none: 'bg-gray-100 text-gray-700',
  };
  const cls = map[v] ?? 'bg-gray-100 text-gray-700';
  return <span className={'inline-block rounded px-2 py-0.5 text-xs font-medium ' + cls}>{v}</span>;
}

function KindPill({ v }: { v: string }) {
  const map: Record<string, string> = {
    split: 'bg-purple-100 text-purple-800',
    merge: 'bg-indigo-100 text-indigo-800',
    hire: 'bg-emerald-100 text-emerald-800',
    redesign: 'bg-sky-100 text-sky-800',
    outsource: 'bg-yellow-100 text-yellow-800',
    automate: 'bg-cyan-100 text-cyan-800',
  };
  const cls = map[v] ?? 'bg-gray-100 text-gray-700';
  return <span className={'inline-block rounded px-2 py-0.5 text-xs font-medium ' + cls}>{v}</span>;
}

function StatusPill({ v }: { v: string }) {
  const map: Record<string, string> = {
    proposed: 'bg-gray-100 text-gray-800',
    approved: 'bg-blue-100 text-blue-800',
    in_flight: 'bg-amber-100 text-amber-800',
    realized: 'bg-emerald-100 text-emerald-800',
    blocked: 'bg-red-100 text-red-800',
    reversed: 'bg-rose-100 text-rose-800',
  };
  const cls = map[v] ?? 'bg-gray-100 text-gray-700';
  return <span className={'inline-block rounded px-2 py-0.5 text-xs font-medium ' + cls}>{v}</span>;
}
