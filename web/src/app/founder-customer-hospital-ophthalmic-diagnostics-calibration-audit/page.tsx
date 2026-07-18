import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { calibration_verdict: string; devices: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_checks: number;
  released: number;
  quarantined: number;
  service_required: number;
  condemned: number;
  fungus_cases: number;
  compliance_pct: number;
};
type TypeRow = {
  device_type: string;
  checks: number;
  released: number;
  quarantined: number;
  avg_abs_iop_offset_mmhg: number | null;
};
type TrendRow = {
  calibration_date: string;
  checks: number;
  released: number;
  quarantined: number;
  service_required: number;
  illumination_faults: number;
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
  eye_unit_code: string;
  device_asset_tag: string;
  device_type: string;
  calibration_date: string;
  calibration_verdict: string;
  iop_cal_offset_mmhg: number | null;
  optics_clarity: string | null;
  alignment_status: string | null;
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
    supabase.rpc('founder_r3190_verdict_rollup'),
    supabase.rpc('founder_r3190_hospital_scorecard'),
    supabase.rpc('founder_r3190_device_type_matrix'),
    supabase.rpc('founder_r3190_daily_trend'),
    supabase.rpc('founder_r3190_capa_status_board'),
    supabase.rpc('founder_r3190_root_cause_pareto'),
    supabase.rpc('founder_r3190_regulatory_impact_digest'),
    supabase.rpc('founder_r3190_high_risk_devices'),
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
    { key: 'calibration_verdict', header: 'Verdict' },
    { key: 'devices', header: 'Devices' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_checks', header: 'Checks' },
    { key: 'released', header: 'Released' },
    { key: 'quarantined', header: 'Quarantined' },
    { key: 'service_required', header: 'Service Reqd' },
    { key: 'condemned', header: 'Condemned' },
    { key: 'fungus_cases', header: 'Fungus' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const typeCols: Column<TypeRow>[] = [
    { key: 'device_type', header: 'Device Type' },
    { key: 'checks', header: 'Checks' },
    { key: 'released', header: 'Released' },
    { key: 'quarantined', header: 'Quarantined' },
    { key: 'avg_abs_iop_offset_mmhg', header: 'Avg |IOP Offset| mmHg' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'calibration_date', header: 'Date' },
    { key: 'checks', header: 'Checks' },
    { key: 'released', header: 'Released' },
    { key: 'quarantined', header: 'Quarantined' },
    { key: 'service_required', header: 'Service Reqd' },
    { key: 'illumination_faults', header: 'Illumination Faults' },
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
    { key: 'eye_unit_code', header: 'Unit' },
    { key: 'device_asset_tag', header: 'Asset' },
    { key: 'device_type', header: 'Type' },
    { key: 'calibration_date', header: 'Date' },
    { key: 'calibration_verdict', header: 'Verdict' },
    { key: 'iop_cal_offset_mmhg', header: 'IOP Offset mmHg' },
    { key: 'optics_clarity', header: 'Optics' },
    { key: 'alignment_status', header: 'Alignment' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Slit-Lamp, Phoropter &amp; Ophthalmic-Diagnostics Calibration Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Ophthalmic QA log — device type &times; illumination &times; IOP-cal offset mmHg &times;
        optics clarity &times; alignment &times; filter wheel &times; chin-rest hygiene &amp; CAPA closure.
        Founder-gated view: calibration verdicts, hospital scorecards, root-cause pareto, and
        regulatory-impact digest across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Calibration verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No calibration checks logged yet."
          rowKey={(r, i) => String(r.calibration_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital calibration scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Device type &times; verdict matrix</h2>
        <DataTable
          rows={typeRows}
          columns={typeCols}
          emptyMessage="No checks by device type."
          rowKey={(r, i) => `${r.device_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily calibration trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.calibration_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk devices queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk devices."
          rowKey={(r, i) => `${r.device_asset_tag}-${r.calibration_date}-${i}`}
        />
      </section>
    </main>
  );
}
