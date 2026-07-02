import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Bottleneck = {
  id: string;
  chain_name: string;
  quarter: string;
  workflow_area: string;
  bottleneck_summary: string;
  patient_throughput_drop_pct: number;
  avg_extra_wait_minutes: number;
  monthly_revenue_at_risk_rupees: number;
  root_cause: string;
  our_equipment_fix: string;
  fix_status: string;
  outcome_throughput_recovery_pct: number | null;
  noted_on: string;
};

type Kpi = {
  total_chains: number;
  total_bottlenecks: number;
  total_revenue_at_risk_rupees: number;
  operational_fixes: number;
  in_install_fixes: number;
  proposed_fixes: number;
  avg_throughput_drop_pct: number;
  avg_recovery_pct: number;
};

type AreaRow = {
  workflow_area: string;
  bottleneck_count: number;
  total_revenue_at_risk_rupees: number;
  avg_throughput_drop_pct: number;
  operational_count: number;
};

type ChainRow = {
  chain_name: string;
  bottleneck_count: number;
  total_revenue_at_risk_rupees: number;
  avg_throughput_drop_pct: number;
  fixes_operational: number;
  fixes_pending: number;
};

type Scorecard = {
  id: string;
  chain_name: string;
  workflow_area: string;
  quarter: string;
  pre_fix_throughput_per_day: number;
  post_fix_throughput_per_day: number | null;
  pre_fix_downtime_hours_month: number;
  post_fix_downtime_hours_month: number | null;
  patient_satisfaction_pre: number;
  patient_satisfaction_post: number | null;
  clinical_incident_count_pre: number;
  clinical_incident_count_post: number | null;
  estimated_revenue_recovery_rupees: number | null;
  expansion_signal: string;
  recorded_on: string;
};

type ExpansionRow = {
  expansion_signal: string;
  chain_count: number;
  total_revenue_recovery_rupees: number;
};

type RootCauseRow = {
  root_cause: string;
  occurrences: number;
  total_revenue_at_risk_rupees: number;
  avg_wait_minutes: number;
};

type DeltaRow = {
  chain_name: string;
  workflow_area: string;
  throughput_delta_pct: number | null;
  downtime_reduction_pct: number | null;
  satisfaction_delta: number | null;
  incident_reduction: number | null;
  expansion_signal: string;
};

function fmtINR(n: number | null | undefined): string {
  if (n === null || n === undefined) return '--';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '--';
  return Number(n).toFixed(1) + '%';
}

function fmtNum(n: number | null | undefined): string {
  if (n === null || n === undefined) return '--';
  return Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, invRes, areaRes, chainRes, scoreRes, expRes, rootRes, deltaRes] = await Promise.all([
    supabase.rpc('rpc_r2803_kpi_summary'),
    supabase.rpc('rpc_r2803_bottleneck_inventory'),
    supabase.rpc('rpc_r2803_workflow_area_rollup'),
    supabase.rpc('rpc_r2803_chain_rollup'),
    supabase.rpc('rpc_r2803_outcome_scorecard'),
    supabase.rpc('rpc_r2803_expansion_signal_rollup'),
    supabase.rpc('rpc_r2803_root_cause_rollup'),
    supabase.rpc('rpc_r2803_outcome_delta'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] as Kpi) ?? {
    total_chains: 0,
    total_bottlenecks: 0,
    total_revenue_at_risk_rupees: 0,
    operational_fixes: 0,
    in_install_fixes: 0,
    proposed_fixes: 0,
    avg_throughput_drop_pct: 0,
    avg_recovery_pct: 0,
  };
  const bottlenecks: Bottleneck[] = (invRes.data as Bottleneck[]) ?? [];
  const areas: AreaRow[] = (areaRes.data as AreaRow[]) ?? [];
  const chains: ChainRow[] = (chainRes.data as ChainRow[]) ?? [];
  const scorecard: Scorecard[] = (scoreRes.data as Scorecard[]) ?? [];
  const expansions: ExpansionRow[] = (expRes.data as ExpansionRow[]) ?? [];
  const rootCauses: RootCauseRow[] = (rootRes.data as RootCauseRow[]) ?? [];
  const deltas: DeltaRow[] = (deltaRes.data as DeltaRow[]) ?? [];

  return (
    <main className="mx-auto max-w-7xl space-y-6 px-4 py-6">
      <header>
        <h1 className="text-2xl font-semibold">Hospital Chain Quarterly Clinical Workflow Bottleneck</h1>
        <p className="text-sm text-neutral-600">
          Chain × workflow × bottleneck × impact × our equipment fix × outcome — round r2803
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <div className="rounded border bg-white p-3">
          <div className="text-xs text-neutral-500">Chains tracked</div>
          <div className="text-xl font-semibold">{fmtNum(kpi.total_chains)}</div>
        </div>
        <div className="rounded border bg-white p-3">
          <div className="text-xs text-neutral-500">Total bottlenecks</div>
          <div className="text-xl font-semibold">{fmtNum(kpi.total_bottlenecks)}</div>
        </div>
        <div className="rounded border bg-white p-3">
          <div className="text-xs text-neutral-500">Revenue at risk / month</div>
          <div className="text-xl font-semibold">{fmtINR(kpi.total_revenue_at_risk_rupees)}</div>
        </div>
        <div className="rounded border bg-white p-3">
          <div className="text-xs text-neutral-500">Avg throughput drop</div>
          <div className="text-xl font-semibold">{fmtPct(kpi.avg_throughput_drop_pct)}</div>
        </div>
        <div className="rounded border bg-white p-3">
          <div className="text-xs text-neutral-500">Fixes operational</div>
          <div className="text-xl font-semibold">{fmtNum(kpi.operational_fixes)}</div>
        </div>
        <div className="rounded border bg-white p-3">
          <div className="text-xs text-neutral-500">Fixes in install</div>
          <div className="text-xl font-semibold">{fmtNum(kpi.in_install_fixes)}</div>
        </div>
        <div className="rounded border bg-white p-3">
          <div className="text-xs text-neutral-500">Fixes proposed</div>
          <div className="text-xl font-semibold">{fmtNum(kpi.proposed_fixes)}</div>
        </div>
        <div className="rounded border bg-white p-3">
          <div className="text-xs text-neutral-500">Avg recovery post-fix</div>
          <div className="text-xl font-semibold">{fmtPct(kpi.avg_recovery_pct)}</div>
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Bottleneck inventory</h2>
        <DataTable
          rows={bottlenecks}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Bottleneck) => r.chain_name },
            { key: 'quarter', header: 'Quarter', render: (r: Bottleneck) => r.quarter },
            { key: 'workflow_area', header: 'Workflow', render: (r: Bottleneck) => r.workflow_area },
            { key: 'bottleneck_summary', header: 'Bottleneck', render: (r: Bottleneck) => r.bottleneck_summary },
            { key: 'patient_throughput_drop_pct', header: 'Drop %', render: (r: Bottleneck) => fmtPct(r.patient_throughput_drop_pct) },
            { key: 'avg_extra_wait_minutes', header: 'Wait (min)', render: (r: Bottleneck) => fmtNum(r.avg_extra_wait_minutes) },
            { key: 'monthly_revenue_at_risk_rupees', header: 'Revenue at risk', render: (r: Bottleneck) => fmtINR(r.monthly_revenue_at_risk_rupees) },
            { key: 'root_cause', header: 'Root cause', render: (r: Bottleneck) => r.root_cause },
            { key: 'our_equipment_fix', header: 'Our fix', render: (r: Bottleneck) => r.our_equipment_fix },
            { key: 'fix_status', header: 'Status', render: (r: Bottleneck) => r.fix_status },
            { key: 'outcome_throughput_recovery_pct', header: 'Recovery %', render: (r: Bottleneck) => fmtPct(r.outcome_throughput_recovery_pct) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Bottleneck, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Workflow area rollup</h2>
        <DataTable
          rows={areas}
          columns={[
            { key: 'workflow_area', header: 'Workflow area', render: (r: AreaRow) => r.workflow_area },
            { key: 'bottleneck_count', header: 'Bottlenecks', render: (r: AreaRow) => fmtNum(r.bottleneck_count) },
            { key: 'total_revenue_at_risk_rupees', header: 'Revenue at risk', render: (r: AreaRow) => fmtINR(r.total_revenue_at_risk_rupees) },
            { key: 'avg_throughput_drop_pct', header: 'Avg drop', render: (r: AreaRow) => fmtPct(r.avg_throughput_drop_pct) },
            { key: 'operational_count', header: 'Fixes live', render: (r: AreaRow) => fmtNum(r.operational_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r: AreaRow, i: number) => String(r.workflow_area ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Chain rollup</h2>
        <DataTable
          rows={chains}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ChainRow) => r.chain_name },
            { key: 'bottleneck_count', header: 'Bottlenecks', render: (r: ChainRow) => fmtNum(r.bottleneck_count) },
            { key: 'total_revenue_at_risk_rupees', header: 'Revenue at risk', render: (r: ChainRow) => fmtINR(r.total_revenue_at_risk_rupees) },
            { key: 'avg_throughput_drop_pct', header: 'Avg drop', render: (r: ChainRow) => fmtPct(r.avg_throughput_drop_pct) },
            { key: 'fixes_operational', header: 'Live fixes', render: (r: ChainRow) => fmtNum(r.fixes_operational) },
            { key: 'fixes_pending', header: 'Pending fixes', render: (r: ChainRow) => fmtNum(r.fixes_pending) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ChainRow, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Root cause rollup</h2>
        <DataTable
          rows={rootCauses}
          columns={[
            { key: 'root_cause', header: 'Root cause', render: (r: RootCauseRow) => r.root_cause },
            { key: 'occurrences', header: 'Occurrences', render: (r: RootCauseRow) => fmtNum(r.occurrences) },
            { key: 'total_revenue_at_risk_rupees', header: 'Revenue at risk', render: (r: RootCauseRow) => fmtINR(r.total_revenue_at_risk_rupees) },
            { key: 'avg_wait_minutes', header: 'Avg wait (min)', render: (r: RootCauseRow) => fmtNum(r.avg_wait_minutes) },
          ]}
          emptyMessage="No data"
          rowKey={(r: RootCauseRow, i: number) => String(r.root_cause ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Outcome scorecard (pre vs post)</h2>
        <DataTable
          rows={scorecard}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Scorecard) => r.chain_name },
            { key: 'workflow_area', header: 'Workflow', render: (r: Scorecard) => r.workflow_area },
            { key: 'quarter', header: 'Quarter', render: (r: Scorecard) => r.quarter },
            { key: 'pre_fix_throughput_per_day', header: 'Pre throughput/day', render: (r: Scorecard) => fmtNum(r.pre_fix_throughput_per_day) },
            { key: 'post_fix_throughput_per_day', header: 'Post throughput/day', render: (r: Scorecard) => fmtNum(r.post_fix_throughput_per_day) },
            { key: 'pre_fix_downtime_hours_month', header: 'Pre downtime hrs', render: (r: Scorecard) => fmtNum(r.pre_fix_downtime_hours_month) },
            { key: 'post_fix_downtime_hours_month', header: 'Post downtime hrs', render: (r: Scorecard) => fmtNum(r.post_fix_downtime_hours_month) },
            { key: 'patient_satisfaction_pre', header: 'CSAT pre', render: (r: Scorecard) => fmtNum(r.patient_satisfaction_pre) },
            { key: 'patient_satisfaction_post', header: 'CSAT post', render: (r: Scorecard) => fmtNum(r.patient_satisfaction_post) },
            { key: 'clinical_incident_count_pre', header: 'Incidents pre', render: (r: Scorecard) => fmtNum(r.clinical_incident_count_pre) },
            { key: 'clinical_incident_count_post', header: 'Incidents post', render: (r: Scorecard) => fmtNum(r.clinical_incident_count_post) },
            { key: 'estimated_revenue_recovery_rupees', header: 'Revenue recovery', render: (r: Scorecard) => fmtINR(r.estimated_revenue_recovery_rupees) },
            { key: 'expansion_signal', header: 'Expansion', render: (r: Scorecard) => r.expansion_signal },
          ]}
          emptyMessage="No data"
          rowKey={(r: Scorecard, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Outcome delta</h2>
        <DataTable
          rows={deltas}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: DeltaRow) => r.chain_name },
            { key: 'workflow_area', header: 'Workflow', render: (r: DeltaRow) => r.workflow_area },
            { key: 'throughput_delta_pct', header: 'Throughput uplift', render: (r: DeltaRow) => fmtPct(r.throughput_delta_pct) },
            { key: 'downtime_reduction_pct', header: 'Downtime cut', render: (r: DeltaRow) => fmtPct(r.downtime_reduction_pct) },
            { key: 'satisfaction_delta', header: 'CSAT delta', render: (r: DeltaRow) => fmtNum(r.satisfaction_delta) },
            { key: 'incident_reduction', header: 'Incidents avoided', render: (r: DeltaRow) => fmtNum(r.incident_reduction) },
            { key: 'expansion_signal', header: 'Expansion', render: (r: DeltaRow) => r.expansion_signal },
          ]}
          emptyMessage="No data"
          rowKey={(r: DeltaRow, i: number) => String(r.chain_name + '|' + r.workflow_area + '|' + i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Expansion signal rollup</h2>
        <DataTable
          rows={expansions}
          columns={[
            { key: 'expansion_signal', header: 'Signal', render: (r: ExpansionRow) => r.expansion_signal },
            { key: 'chain_count', header: 'Chains', render: (r: ExpansionRow) => fmtNum(r.chain_count) },
            { key: 'total_revenue_recovery_rupees', header: 'Recovery value', render: (r: ExpansionRow) => fmtINR(r.total_revenue_recovery_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ExpansionRow, i: number) => String(r.expansion_signal ?? i)}
        />
      </section>
    </main>
  );
}
