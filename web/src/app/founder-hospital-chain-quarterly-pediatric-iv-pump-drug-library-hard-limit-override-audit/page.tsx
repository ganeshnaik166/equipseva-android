import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/ui/DataTable';
import type { Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ChainRollup = { chain_code: string; total_overrides: number; critical_overrides: number; adverse_events: number; near_misses: number; deaths: number; avg_pct_over: number };
type DrugRisk = { drug_name: string; overrides: number; max_pct_over: number; adverse_or_death: number; unreviewed_by_pharmacy: number };
type Seniority = { prescriber_seniority: string; overrides: number; avg_pct: number; adverse_events: number };
type Reason = { override_reason_code: string; overrides: number; share_pct: number };
type Findings = { chain_code: string; critical_open: number; major_open: number; minor_open: number; total_open: number };
type CritDetail = { chain_code: string; hospital_site: string; drug_name: string; pct_over: number; outcome: string; prescriber_seniority: string; overridden_at: string };
type KPI = { quarter: string; total_overrides: number; critical_pct: number; adverse_or_death: number; pharmacy_review_rate_pct: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [rollup, drugs, seniority, reasons, findings, crit, kpis] = await Promise.all([
    supabase.rpc('r3067_chain_override_rollup'),
    supabase.rpc('r3067_drug_risk_ranking'),
    supabase.rpc('r3067_seniority_breakdown'),
    supabase.rpc('r3067_reason_distribution'),
    supabase.rpc('r3067_findings_open_by_chain'),
    supabase.rpc('r3067_critical_overrides_detail'),
    supabase.rpc('r3067_quarterly_kpis'),
  ]);

  const rollupRows: ChainRollup[] = (rollup.data as ChainRollup[]) ?? [];
  const drugRows: DrugRisk[] = (drugs.data as DrugRisk[]) ?? [];
  const senRows: Seniority[] = (seniority.data as Seniority[]) ?? [];
  const reasonRows: Reason[] = (reasons.data as Reason[]) ?? [];
  const findingRows: Findings[] = (findings.data as Findings[]) ?? [];
  const critRows: CritDetail[] = (crit.data as CritDetail[]) ?? [];
  const kpiRows: KPI[] = (kpis.data as KPI[]) ?? [];

  const rollupCols: Column<ChainRollup>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Total', accessor: (r) => r.total_overrides },
    { header: 'Critical (>=50%)', accessor: (r) => r.critical_overrides },
    { header: 'Adverse', accessor: (r) => r.adverse_events },
    { header: 'Near Miss', accessor: (r) => r.near_misses },
    { header: 'Deaths', accessor: (r) => r.deaths },
    { header: 'Avg % Over', accessor: (r) => r.avg_pct_over },
  ];

  const drugCols: Column<DrugRisk>[] = [
    { header: 'Drug', accessor: (r) => r.drug_name },
    { header: 'Overrides', accessor: (r) => r.overrides },
    { header: 'Max % Over', accessor: (r) => r.max_pct_over },
    { header: 'Adverse/Death', accessor: (r) => r.adverse_or_death },
    { header: 'No Pharm Review', accessor: (r) => r.unreviewed_by_pharmacy },
  ];

  const senCols: Column<Seniority>[] = [
    { header: 'Seniority', accessor: (r) => r.prescriber_seniority },
    { header: 'Overrides', accessor: (r) => r.overrides },
    { header: 'Avg %', accessor: (r) => r.avg_pct },
    { header: 'Adverse Events', accessor: (r) => r.adverse_events },
  ];

  const reasonCols: Column<Reason>[] = [
    { header: 'Reason', accessor: (r) => r.override_reason_code },
    { header: 'Overrides', accessor: (r) => r.overrides },
    { header: 'Share %', accessor: (r) => r.share_pct },
  ];

  const findingCols: Column<Findings>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Critical Open', accessor: (r) => r.critical_open },
    { header: 'Major Open', accessor: (r) => r.major_open },
    { header: 'Minor Open', accessor: (r) => r.minor_open },
    { header: 'Total Open', accessor: (r) => r.total_open },
  ];

  const critCols: Column<CritDetail>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Site', accessor: (r) => r.hospital_site },
    { header: 'Drug', accessor: (r) => r.drug_name },
    { header: '% Over', accessor: (r) => r.pct_over },
    { header: 'Outcome', accessor: (r) => r.outcome },
    { header: 'Prescriber', accessor: (r) => r.prescriber_seniority },
    { header: 'When', accessor: (r) => new Date(r.overridden_at).toLocaleString() },
  ];

  const kpiCols: Column<KPI>[] = [
    { header: 'Quarter', accessor: (r) => r.quarter },
    { header: 'Total Overrides', accessor: (r) => r.total_overrides },
    { header: 'Critical %', accessor: (r) => r.critical_pct },
    { header: 'Adverse/Death', accessor: (r) => r.adverse_or_death },
    { header: 'Pharmacy Review %', accessor: (r) => r.pharmacy_review_rate_pct },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Pediatric IV-Pump Drug-Library Hard-Limit Override Audit</h1>
        <p className="text-sm text-gray-600">Round r3067 — chain-level rollup of pediatric smart-pump library overrides & audit findings.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly KPIs</h2>
        <DataTable rows={kpiRows} columns={kpiCols} emptyMessage="No KPI rows" rowKey={(r, i) => String((r as KPI).quarter ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain Override Rollup</h2>
        <DataTable rows={rollupRows} columns={rollupCols} emptyMessage="No chain rollup" rowKey={(r, i) => String((r as ChainRollup).chain_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Drug Risk Ranking</h2>
        <DataTable rows={drugRows} columns={drugCols} emptyMessage="No drug rows" rowKey={(r, i) => String((r as DrugRisk).drug_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Prescriber Seniority Breakdown</h2>
        <DataTable rows={senRows} columns={senCols} emptyMessage="No seniority data" rowKey={(r, i) => String((r as Seniority).prescriber_seniority ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Override Reason Distribution</h2>
        <DataTable rows={reasonRows} columns={reasonCols} emptyMessage="No reasons" rowKey={(r, i) => String((r as Reason).override_reason_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Audit Findings Open by Chain</h2>
        <DataTable rows={findingRows} columns={findingCols} emptyMessage="No findings" rowKey={(r, i) => String((r as Findings).chain_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Critical Override Detail (&gt;=50% over or harm)</h2>
        <DataTable rows={critRows} columns={critCols} emptyMessage="No critical overrides" rowKey={(r, i) => String((r as CritDetail).hospital_site ?? i) + '-' + i} />
      </section>
    </div>
  );
}
