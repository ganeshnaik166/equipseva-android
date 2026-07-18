import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { audit_verdict: string; instruments: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_instruments: number;
  fit_for_use: number;
  quarantined: number;
  withdrawn: number;
  torque_fail: number;
  runout_fail: number;
  fit_pct: number;
};
type TypeRow = {
  instrument_type: string;
  power_source: string;
  instruments: number;
  fit_for_use: number;
  avg_rpm_deviation_pct: number | null;
  avg_sterilization_cycles: number;
};
type TrendRow = {
  test_date: string;
  instruments_tested: number;
  torque_pass: number;
  torque_fail: number;
  runout_fail: number;
  lubrication_missed: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_or_escalated: number;
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
  instrument_asset_tag: string;
  instrument_type: string;
  test_date: string;
  audit_verdict: string;
  torque_verdict: string | null;
  chuck_runout_verdict: string | null;
  battery_hose_condition: string;
  sterilization_cycle_count: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    typeRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3222_verdict_rollup'),
    supabase.rpc('founder_r3222_hospital_scorecard'),
    supabase.rpc('founder_r3222_instrument_type_matrix'),
    supabase.rpc('founder_r3222_daily_test_trend'),
    supabase.rpc('founder_r3222_capa_status_board'),
    supabase.rpc('founder_r3222_root_cause_pareto'),
    supabase.rpc('founder_r3222_regulatory_impact_digest'),
    supabase.rpc('founder_r3222_high_risk_instruments'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const typeRows: TypeRow[] = (typeRes.data as TypeRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'instruments', header: 'Instruments' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_instruments', header: 'Instruments' },
    { key: 'fit_for_use', header: 'Fit for Use' },
    { key: 'quarantined', header: 'Quarantined' },
    { key: 'withdrawn', header: 'Withdrawn' },
    { key: 'torque_fail', header: 'Torque Fail' },
    { key: 'runout_fail', header: 'Runout Fail' },
    { key: 'fit_pct', header: 'Fit %' },
  ];

  const typeCols: Column<TypeRow>[] = [
    { key: 'instrument_type', header: 'Instrument Type' },
    { key: 'power_source', header: 'Power Source' },
    { key: 'instruments', header: 'Instruments' },
    { key: 'fit_for_use', header: 'Fit for Use' },
    { key: 'avg_rpm_deviation_pct', header: 'Avg RPM Dev %' },
    { key: 'avg_sterilization_cycles', header: 'Avg Steri Cycles' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'test_date', header: 'Date' },
    { key: 'instruments_tested', header: 'Tested' },
    { key: 'torque_pass', header: 'Torque Pass' },
    { key: 'torque_fail', header: 'Torque Fail' },
    { key: 'runout_fail', header: 'Runout Fail/Borderline' },
    { key: 'lubrication_missed', header: 'Lubrication Missed' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_or_escalated', header: 'Overdue / Escalated' },
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
    { key: 'instrument_asset_tag', header: 'Asset' },
    { key: 'instrument_type', header: 'Type' },
    { key: 'test_date', header: 'Date' },
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'torque_verdict', header: 'Torque' },
    { key: 'chuck_runout_verdict', header: 'Runout' },
    { key: 'battery_hose_condition', header: 'Battery/Hose' },
    { key: 'sterilization_cycle_count', header: 'Steri Cycles' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Surgical-Drill, Saw &amp; Powered-Instrument Torque-Safety Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Powered instrument QA log — instrument type &times; RPM accuracy &times; torque output &times;
        battery/hose condition &times; chuck runout &times; sterilization-cycle count &times; lubrication
        &amp; CAPA closure. Founder-gated view: audit verdicts, hospital scorecards, root-cause pareto,
        and regulatory-impact digest across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Audit verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No instrument audits logged yet."
          rowKey={(r, i) => String(r.audit_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital safety scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Instrument type &times; power source matrix</h2>
        <DataTable
          rows={typeRows}
          columns={typeCols}
          emptyMessage="No instruments by type."
          rowKey={(r, i) => `${r.instrument_type}-${r.power_source}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Torque &amp; runout daily test trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.test_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk instruments queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk instruments."
          rowKey={(r, i) => `${r.instrument_asset_tag}-${r.test_date}-${i}`}
        />
      </section>
    </main>
  );
}
