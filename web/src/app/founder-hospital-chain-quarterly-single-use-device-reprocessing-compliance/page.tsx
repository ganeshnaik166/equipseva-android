import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Column<T> = { key: string; header: string; render?: (row: T) => React.ReactNode };

type ChainRollup = {
  id?: string;
  chain_name: string;
  branches_audited: number;
  avg_compliance_pct: number;
  critical_violations: number;
  total_liability_rupees: number;
  adverse_events: number;
};

type BranchRisk = {
  id?: string;
  chain_name: string;
  branch_name: string;
  branch_city: string;
  device_category: string;
  compliance_score_pct: number;
  violation_severity: string;
  liability_rupees: number;
  adverse_events: number;
};

type DeviceBreakdown = {
  id?: string;
  device_category: string;
  audits: number;
  avg_reuse_cycles: number;
  avg_compliance_pct: number;
  total_adverse_events: number;
  total_liability: number;
};

type SterilizationEfficacy = {
  id?: string;
  sterilization_method: string;
  sample_count: number;
  avg_bioburden_pass: number;
  avg_endotoxin_pass: number;
  critical_count: number;
};

type CorrectiveAction = {
  id?: string;
  chain_name: string;
  branch_name: string;
  action_type: string;
  action_priority: string;
  current_status: string;
  completion_pct: number;
  target_closure_date: string;
  capex_rupees: number;
  opex_rupees: number;
};

type AmcOpportunity = {
  id?: string;
  chain_name: string;
  total_amc_opportunity_rupees: number;
  engineer_assigned_count: number;
  open_actions: number;
  capex_total_rupees: number;
};

type QuarterlyKpis = {
  total_audits: number;
  total_branches: number;
  total_chains: number;
  avg_compliance_pct: number;
  critical_branches: number;
  total_liability_rupees: number;
  total_adverse_events: number;
  total_amc_pipeline_rupees: number;
};

function inr(n: number | null | undefined): string {
  if (!n) return '₹0';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    rollup,
    branchRisk,
    deviceBreakdown,
    sterilization,
    backlog,
    amcOpps,
    kpis,
  ] = await Promise.all([
    supabase.rpc('rpc_r2891_chain_compliance_rollup'),
    supabase.rpc('rpc_r2891_branch_risk_ranking'),
    supabase.rpc('rpc_r2891_device_category_breakdown'),
    supabase.rpc('rpc_r2891_sterilization_method_efficacy'),
    supabase.rpc('rpc_r2891_corrective_action_backlog'),
    supabase.rpc('rpc_r2891_amc_upsell_opportunities'),
    supabase.rpc('rpc_r2891_quarterly_kpis'),
  ]);

  const rollupRows: ChainRollup[] = (rollup.data as ChainRollup[]) || [];
  const branchRows: BranchRisk[] = (branchRisk.data as BranchRisk[]) || [];
  const deviceRows: DeviceBreakdown[] = (deviceBreakdown.data as DeviceBreakdown[]) || [];
  const sterilizationRows: SterilizationEfficacy[] = (sterilization.data as SterilizationEfficacy[]) || [];
  const backlogRows: CorrectiveAction[] = (backlog.data as CorrectiveAction[]) || [];
  const amcRows: AmcOpportunity[] = (amcOpps.data as AmcOpportunity[]) || [];
  const kpi: QuarterlyKpis | null = (kpis.data as QuarterlyKpis[] | null)?.[0] ?? null;

  const rollupCols: Column<ChainRollup>[] = [
    { key: 'chain_name', header: 'Chain' },
    { key: 'branches_audited', header: 'Branches' },
    { key: 'avg_compliance_pct', header: 'Avg Compliance %', render: (r) => `${r.avg_compliance_pct}%` },
    { key: 'critical_violations', header: 'Critical' },
    { key: 'adverse_events', header: 'Adverse Events' },
    { key: 'total_liability_rupees', header: 'Liability', render: (r) => inr(r.total_liability_rupees) },
  ];

  const branchCols: Column<BranchRisk>[] = [
    { key: 'chain_name', header: 'Chain' },
    { key: 'branch_name', header: 'Branch' },
    { key: 'branch_city', header: 'City' },
    { key: 'device_category', header: 'Device' },
    { key: 'compliance_score_pct', header: 'Score %', render: (r) => `${r.compliance_score_pct}%` },
    { key: 'violation_severity', header: 'Severity' },
    { key: 'adverse_events', header: 'AEs' },
    { key: 'liability_rupees', header: 'Liability', render: (r) => inr(r.liability_rupees) },
  ];

  const deviceCols: Column<DeviceBreakdown>[] = [
    { key: 'device_category', header: 'Device Category' },
    { key: 'audits', header: 'Audits' },
    { key: 'avg_reuse_cycles', header: 'Avg Reuse Cycles' },
    { key: 'avg_compliance_pct', header: 'Avg Compliance %', render: (r) => `${r.avg_compliance_pct}%` },
    { key: 'total_adverse_events', header: 'Adverse Events' },
    { key: 'total_liability', header: 'Liability', render: (r) => inr(r.total_liability) },
  ];

  const sterCols: Column<SterilizationEfficacy>[] = [
    { key: 'sterilization_method', header: 'Method' },
    { key: 'sample_count', header: 'Samples' },
    { key: 'avg_bioburden_pass', header: 'Bioburden Pass %', render: (r) => `${r.avg_bioburden_pass}%` },
    { key: 'avg_endotoxin_pass', header: 'Endotoxin Pass %', render: (r) => `${r.avg_endotoxin_pass}%` },
    { key: 'critical_count', header: 'Critical Findings' },
  ];

  const backlogCols: Column<CorrectiveAction>[] = [
    { key: 'chain_name', header: 'Chain' },
    { key: 'branch_name', header: 'Branch' },
    { key: 'action_type', header: 'Action' },
    { key: 'action_priority', header: 'Priority' },
    { key: 'current_status', header: 'Status' },
    { key: 'completion_pct', header: 'Done %', render: (r) => `${r.completion_pct}%` },
    { key: 'target_closure_date', header: 'Target' },
    { key: 'capex_rupees', header: 'Capex', render: (r) => inr(r.capex_rupees) },
    { key: 'opex_rupees', header: 'Opex', render: (r) => inr(r.opex_rupees) },
  ];

  const amcCols: Column<AmcOpportunity>[] = [
    { key: 'chain_name', header: 'Chain' },
    { key: 'total_amc_opportunity_rupees', header: 'AMC Pipeline', render: (r) => inr(r.total_amc_opportunity_rupees) },
    { key: 'engineer_assigned_count', header: 'Engineers Assigned' },
    { key: 'open_actions', header: 'Open Actions' },
    { key: 'capex_total_rupees', header: 'Capex Required', render: (r) => inr(r.capex_total_rupees) },
  ];

  return (
    <main className="mx-auto max-w-7xl px-6 py-10">
      <header className="mb-8">
        <h1 className="text-3xl font-semibold tracking-tight">Hospital Chain Quarterly Single-Use-Device Reprocessing Compliance</h1>
        <p className="mt-2 text-sm text-gray-600">
          Multi-branch rollup of SUD reprocessing audits across hospital chains — bioburden, endotoxin,
          reuse-cycle limits, FDA 510(k) clearance, sterilization efficacy & corrective-action backlog.
          Drives AMC upsell into infection-control & biomedical CSSD lanes.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-4 md:grid-cols-4 mb-10">
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-gray-500">Audits</div>
          <div className="mt-1 text-2xl font-semibold">{kpi?.total_audits ?? 0}</div>
          <div className="text-xs text-gray-500">{kpi?.total_branches ?? 0} branches · {kpi?.total_chains ?? 0} chains</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-gray-500">Avg Compliance</div>
          <div className="mt-1 text-2xl font-semibold">{kpi?.avg_compliance_pct ?? 0}%</div>
          <div className="text-xs text-gray-500">target &gt;= 90%</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-gray-500">Critical Branches</div>
          <div className="mt-1 text-2xl font-semibold text-red-600">{kpi?.critical_branches ?? 0}</div>
          <div className="text-xs text-gray-500">{kpi?.total_adverse_events ?? 0} adverse events</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-gray-500">Liability Exposure</div>
          <div className="mt-1 text-2xl font-semibold">{inr(kpi?.total_liability_rupees ?? 0)}</div>
          <div className="text-xs text-gray-500">AMC pipeline {inr(kpi?.total_amc_pipeline_rupees ?? 0)}</div>
        </div>
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold">Chain Compliance Rollup</h2>
        <DataTable
          rows={rollupRows}
          columns={rollupCols}
          emptyMessage="No chain data yet."
          rowKey={(r, i) => String((r as ChainRollup).chain_name ?? i)}
        />
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold">Branch Risk Ranking (lowest compliance first)</h2>
        <DataTable
          rows={branchRows}
          columns={branchCols}
          emptyMessage="No branch risk records."
          rowKey={(r, i) => String((r as BranchRisk).branch_name ?? i)}
        />
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold">Device Category Breakdown</h2>
        <DataTable
          rows={deviceRows}
          columns={deviceCols}
          emptyMessage="No device breakdown."
          rowKey={(r, i) => String((r as DeviceBreakdown).device_category ?? i)}
        />
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold">Sterilization Method Efficacy</h2>
        <DataTable
          rows={sterilizationRows}
          columns={sterCols}
          emptyMessage="No sterilization data."
          rowKey={(r, i) => String((r as SterilizationEfficacy).sterilization_method ?? i)}
        />
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold">Corrective Action Backlog</h2>
        <DataTable
          rows={backlogRows}
          columns={backlogCols}
          emptyMessage="No corrective actions outstanding."
          rowKey={(r, i) => String((r as CorrectiveAction).id ?? i)}
        />
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold">AMC Upsell Opportunities by Chain</h2>
        <DataTable
          rows={amcRows}
          columns={amcCols}
          emptyMessage="No AMC opportunities surfaced."
          rowKey={(r, i) => String((r as AmcOpportunity).chain_name ?? i)}
        />
      </section>
    </main>
  );
}
