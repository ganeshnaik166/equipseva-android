import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { verdict: string; audits: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  passed: number;
  conditional: number;
  failed: number;
  quarantined: number;
  recalls: number;
  waterline_alerts: number;
  compliance_pct: number;
};
type MatrixRow = {
  compressor_type: string;
  suction_type: string;
  audits: number;
  passed: number;
  avg_pressure_bar: number;
  avg_suction_lpm: number;
};
type TrendRow = {
  audit_date: string;
  total_audits: number;
  passed: number;
  failed: number;
  waterline_alerts: number;
  avg_suction_lpm: number;
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
  clinic_room_code: string;
  chair_asset_tag: string;
  audit_date: string;
  verdict: string;
  oil_moisture_check: string | null;
  amalgam_separator_status: string | null;
  anti_retraction_valve: string | null;
  waterline_cfu_per_ml: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3162_verdict_rollup'),
    supabase.rpc('founder_r3162_hospital_scorecard'),
    supabase.rpc('founder_r3162_compressor_suction_matrix'),
    supabase.rpc('founder_r3162_audit_daily_trend'),
    supabase.rpc('founder_r3162_capa_status_board'),
    supabase.rpc('founder_r3162_root_cause_pareto'),
    supabase.rpc('founder_r3162_regulatory_impact_digest'),
    supabase.rpc('founder_r3162_high_risk_audits'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'verdict', header: 'Verdict' },
    { key: 'audits', header: 'Audits' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'passed', header: 'Passed' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'failed', header: 'Failed' },
    { key: 'quarantined', header: 'Quarantined' },
    { key: 'recalls', header: 'Recalls' },
    { key: 'waterline_alerts', header: 'Waterline Alerts' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'compressor_type', header: 'Compressor' },
    { key: 'suction_type', header: 'Suction' },
    { key: 'audits', header: 'Audits' },
    { key: 'passed', header: 'Passed' },
    { key: 'avg_pressure_bar', header: 'Avg Pressure (bar)' },
    { key: 'avg_suction_lpm', header: 'Avg Suction (L/min)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed / Quar / Recall' },
    { key: 'waterline_alerts', header: 'Waterline Alerts' },
    { key: 'avg_suction_lpm', header: 'Avg Suction (L/min)' },
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
    { key: 'clinic_room_code', header: 'Room' },
    { key: 'chair_asset_tag', header: 'Chair' },
    { key: 'audit_date', header: 'Date' },
    { key: 'verdict', header: 'Verdict' },
    { key: 'oil_moisture_check', header: 'Oil / Moisture' },
    { key: 'amalgam_separator_status', header: 'Amalgam Separator' },
    { key: 'anti_retraction_valve', header: 'Anti-Retraction' },
    { key: 'waterline_cfu_per_ml', header: 'Waterline CFU/mL' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Dental Chair Compressor &amp; Suction-Line Hygiene Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Dental unit QA log — compressor pressure &amp; oil/moisture &times; suction flow (L/min) &times;
        amalgam separator &times; waterline CFU/mL &times; anti-retraction valve &times; handpiece
        lubrication &amp; CAPA closure. Founder-gated view: verdict rollup, hospital scorecards,
        root-cause pareto, and regulatory-impact digest across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No audits logged yet."
          rowKey={(r, i) => String(r.verdict ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Compressor &times; suction matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No audits by compressor/suction."
          rowKey={(r, i) => `${r.compressor_type}-${r.suction_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily audit trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.audit_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk audits queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk audits."
          rowKey={(r, i) => `${r.chair_asset_tag}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
