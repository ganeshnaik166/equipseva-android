import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { cycle_verdict: string; cycles: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_cycles: number;
  released: number;
  quarantined: number;
  recalls: number;
  bd_fail: number;
  vl_fail: number;
  bi_positive: number;
  compliance_pct: number;
};
type LoadProgRow = {
  load_type: string;
  program_name: string;
  cycles: number;
  released: number;
  avg_peak_temp: number;
};
type TrendRow = {
  cycle_date: string;
  bd_pass: number;
  bd_fail: number;
  vl_pass: number;
  vl_fail: number;
  vl_borderline: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type RegRow = {
  regulatory_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  hospital_name: string;
  ot_room_code: string;
  autoclave_asset_tag: string;
  cycle_date: string;
  cycle_verdict: string;
  bowie_dick_result: string | null;
  vacuum_leak_verdict: string | null;
  bi_result: string | null;
  helix_test_result: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    loadProgRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3136_cycle_verdict_rollup'),
    supabase.rpc('founder_r3136_hospital_scorecard'),
    supabase.rpc('founder_r3136_load_program_matrix'),
    supabase.rpc('founder_r3136_bd_vl_daily_trend'),
    supabase.rpc('founder_r3136_capa_status_board'),
    supabase.rpc('founder_r3136_root_cause_pareto'),
    supabase.rpc('founder_r3136_regulatory_impact_digest'),
    supabase.rpc('founder_r3136_high_risk_cycles'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const loadProgRows: LoadProgRow[] = (loadProgRes.data as LoadProgRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'cycle_verdict', header: 'Verdict' },
    { key: 'cycles', header: 'Cycles' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_cycles', header: 'Cycles' },
    { key: 'released', header: 'Released' },
    { key: 'quarantined', header: 'Quarantined' },
    { key: 'recalls', header: 'Recalls' },
    { key: 'bd_fail', header: 'BD Fail' },
    { key: 'vl_fail', header: 'VL Fail' },
    { key: 'bi_positive', header: 'BI+' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const loadProgCols: Column<LoadProgRow>[] = [
    { key: 'load_type', header: 'Load Type' },
    { key: 'program_name', header: 'Program' },
    { key: 'cycles', header: 'Cycles' },
    { key: 'released', header: 'Released' },
    { key: 'avg_peak_temp', header: 'Avg Peak °C' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'cycle_date', header: 'Date' },
    { key: 'bd_pass', header: 'BD Pass' },
    { key: 'bd_fail', header: 'BD Fail' },
    { key: 'vl_pass', header: 'VL Pass' },
    { key: 'vl_fail', header: 'VL Fail' },
    { key: 'vl_borderline', header: 'VL Borderline' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Regulatory Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'ot_room_code', header: 'OT' },
    { key: 'autoclave_asset_tag', header: 'Asset' },
    { key: 'cycle_date', header: 'Date' },
    { key: 'cycle_verdict', header: 'Verdict' },
    { key: 'bowie_dick_result', header: 'BD' },
    { key: 'vacuum_leak_verdict', header: 'VL' },
    { key: 'bi_result', header: 'BI' },
    { key: 'helix_test_result', header: 'Helix' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital OT Autoclave Sterilization Cycle Bowie-Dick & Vacuum Leak Compliance Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Steam autoclave cycle log — load type × program × Bowie-Dick × vacuum-leak ×
        biological indicator × helix test & CAPA closure. Founder-gated view: cycles verdicts,
        hospital scorecards, root-cause pareto, and regulatory-impact digest across NABH & CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Cycle verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No cycles logged yet."
          rowKey={(r, i) => String(r.cycle_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital compliance scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Load type × program matrix</h2>
        <DataTable
          rows={loadProgRows}
          columns={loadProgCols}
          emptyMessage="No cycles by program."
          rowKey={(r, i) => `${r.load_type}-${r.program_name}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Bowie-Dick & vacuum leak daily trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.cycle_date ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA findings."
          rowKey={(r, i) => String(r.capa_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk cycles queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk cycles."
          rowKey={(r, i) => `${r.autoclave_asset_tag}-${r.cycle_date}-${i}`}
        />
      </section>
    </main>
  );
}
