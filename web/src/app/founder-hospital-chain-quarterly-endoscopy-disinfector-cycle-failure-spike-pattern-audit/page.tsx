import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/ui/DataTable';
import type { Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ChainRollup = { chain_code: string; cycles_run: number; cycles_failed: number; fail_rate_pct: number; spike_quarters: number };
type ModelBreakdown = { disinfector_model: string; total_cycles: number; total_failures: number; sites_affected: number };
type QuarterTrend = { quarter: string; fiscal_year: number; spikes: number; failed_cycles: number };
type FailurePareto = { failure_mode: string; occurrences: number; failed_cycles: number };
type SeverityRow = { severity: string; open_count: number; total_cost_rupees: number; exposed_patients: number };
type RiskSite = { chain_code: string; hospital_site: string; failed_cycles: number; fail_rate_pct: number; audit_status: string };
type FindingSummary = { finding_type: string; finding_count: number; flagged_sites: number; cost_rupees: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [chainR, modelR, qtrR, paretoR, sevR, siteR, findR] = await Promise.all([
    supabase.rpc('r3003_chain_failure_rollup'),
    supabase.rpc('r3003_model_failure_breakdown'),
    supabase.rpc('r3003_quarter_spike_trend'),
    supabase.rpc('r3003_failure_mode_pareto'),
    supabase.rpc('r3003_open_findings_by_severity'),
    supabase.rpc('r3003_top_risk_sites'),
    supabase.rpc('r3003_finding_type_summary'),
  ]);

  const chains = (chainR.data ?? []) as ChainRollup[];
  const models = (modelR.data ?? []) as ModelBreakdown[];
  const qtrs = (qtrR.data ?? []) as QuarterTrend[];
  const pareto = (paretoR.data ?? []) as FailurePareto[];
  const sev = (sevR.data ?? []) as SeverityRow[];
  const sites = (siteR.data ?? []) as RiskSite[];
  const finds = (findR.data ?? []) as FindingSummary[];

  const chainCols: Column<ChainRollup>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Cycles', accessor: (r) => r.cycles_run },
    { header: 'Failed', accessor: (r) => r.cycles_failed },
    { header: 'Fail %', accessor: (r) => r.fail_rate_pct },
    { header: 'Spike Qtrs', accessor: (r) => r.spike_quarters },
  ];

  const modelCols: Column<ModelBreakdown>[] = [
    { header: 'Model', accessor: (r) => r.disinfector_model },
    { header: 'Cycles', accessor: (r) => r.total_cycles },
    { header: 'Failures', accessor: (r) => r.total_failures },
    { header: 'Sites', accessor: (r) => r.sites_affected },
  ];

  const qtrCols: Column<QuarterTrend>[] = [
    { header: 'Quarter', accessor: (r) => r.quarter },
    { header: 'FY', accessor: (r) => r.fiscal_year },
    { header: 'Spikes', accessor: (r) => r.spikes },
    { header: 'Failed Cycles', accessor: (r) => r.failed_cycles },
  ];

  const paretoCols: Column<FailurePareto>[] = [
    { header: 'Failure Mode', accessor: (r) => r.failure_mode },
    { header: 'Occurrences', accessor: (r) => r.occurrences },
    { header: 'Failed Cycles', accessor: (r) => r.failed_cycles },
  ];

  const sevCols: Column<SeverityRow>[] = [
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Open', accessor: (r) => r.open_count },
    { header: 'Cost (Rs)', accessor: (r) => r.total_cost_rupees },
    { header: 'Exposed', accessor: (r) => r.exposed_patients },
  ];

  const siteCols: Column<RiskSite>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Site', accessor: (r) => r.hospital_site },
    { header: 'Failed', accessor: (r) => r.failed_cycles },
    { header: 'Fail %', accessor: (r) => r.fail_rate_pct },
    { header: 'Audit', accessor: (r) => r.audit_status },
  ];

  const findCols: Column<FindingSummary>[] = [
    { header: 'Finding Type', accessor: (r) => r.finding_type },
    { header: 'Count', accessor: (r) => r.finding_count },
    { header: 'Flagged Sites', accessor: (r) => r.flagged_sites },
    { header: 'Cost (Rs)', accessor: (r) => r.cost_rupees },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Endoscopy Disinfector Cycle-Failure Spike Pattern Audit</h1>
        <p className="text-sm text-gray-600">Round r3003 — chain-level disinfector cycle fail rates & spike findings.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain failure rollup</h2>
        <DataTable
          rows={chains}
          columns={chainCols}
          emptyMessage="No chain data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Model breakdown</h2>
        <DataTable
          rows={models}
          columns={modelCols}
          emptyMessage="No model data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarter spike trend</h2>
        <DataTable
          rows={qtrs}
          columns={qtrCols}
          emptyMessage="No quarter data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Failure mode pareto</h2>
        <DataTable
          rows={pareto}
          columns={paretoCols}
          emptyMessage="No pareto data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open findings by severity</h2>
        <DataTable
          rows={sev}
          columns={sevCols}
          emptyMessage="No severity data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top risk sites</h2>
        <DataTable
          rows={sites}
          columns={siteCols}
          emptyMessage="No site data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Finding type summary</h2>
        <DataTable
          rows={finds}
          columns={findCols}
          emptyMessage="No finding data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>
    </div>
  );
}
