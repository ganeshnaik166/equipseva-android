import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { cert_verdict: string; cabinets: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_checks: number;
  certified: number;
  conditional: number;
  failed: number;
  hepa_leak_fail: number;
  particle_out_of_spec: number;
  smoke_fail: number;
  pass_pct: number;
};
type MatrixRow = {
  cabinet_type: string;
  particle_count_iso_class: string;
  cabinets: number;
  certified: number;
  avg_inflow_velocity_ms: number;
  avg_uv_lamp_hours: number;
};
type TrendRow = {
  check_date: string;
  checks: number;
  certified: number;
  failed: number;
  hepa_leak_fail: number;
  particle_out_of_spec: number;
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
  cabinet_code: string;
  cabinet_type: string;
  check_date: string;
  cert_verdict: string;
  hepa_filter_leak_test: string | null;
  particle_count_iso_class: string | null;
  smoke_pattern_test: string | null;
  cert_valid_until: string | null;
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
    supabase.rpc('founder_r3263_cert_verdict_rollup'),
    supabase.rpc('founder_r3263_hospital_scorecard'),
    supabase.rpc('founder_r3263_cabinet_type_iso_matrix'),
    supabase.rpc('founder_r3263_daily_cert_trend'),
    supabase.rpc('founder_r3263_capa_status_board'),
    supabase.rpc('founder_r3263_root_cause_pareto'),
    supabase.rpc('founder_r3263_regulatory_impact_digest'),
    supabase.rpc('founder_r3263_high_risk_queue'),
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
    { key: 'cert_verdict', header: 'Cert Verdict' },
    { key: 'cabinets', header: 'Cabinets' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_checks', header: 'Checks' },
    { key: 'certified', header: 'Certified' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'failed', header: 'Failed' },
    { key: 'hepa_leak_fail', header: 'HEPA Leak Fail' },
    { key: 'particle_out_of_spec', header: 'Particle OOS' },
    { key: 'smoke_fail', header: 'Smoke Fail' },
    { key: 'pass_pct', header: 'Pass %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'cabinet_type', header: 'Cabinet Type' },
    { key: 'particle_count_iso_class', header: 'ISO Class' },
    { key: 'cabinets', header: 'Cabinets' },
    { key: 'certified', header: 'Certified' },
    { key: 'avg_inflow_velocity_ms', header: 'Avg Inflow m/s' },
    { key: 'avg_uv_lamp_hours', header: 'Avg UV Lamp Hrs' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'check_date', header: 'Date' },
    { key: 'checks', header: 'Checks' },
    { key: 'certified', header: 'Certified' },
    { key: 'failed', header: 'Failed' },
    { key: 'hepa_leak_fail', header: 'HEPA Leak Fail' },
    { key: 'particle_out_of_spec', header: 'Particle OOS' },
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
    { key: 'cabinet_code', header: 'Cabinet' },
    { key: 'cabinet_type', header: 'Type' },
    { key: 'check_date', header: 'Date' },
    { key: 'cert_verdict', header: 'Verdict' },
    { key: 'hepa_filter_leak_test', header: 'HEPA Leak' },
    { key: 'particle_count_iso_class', header: 'ISO Class' },
    { key: 'smoke_pattern_test', header: 'Smoke' },
    { key: 'cert_valid_until', header: 'Cert Valid Until' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Biosafety-Cabinet, Laminar-Flow Hood &amp; Cytotoxic-Isolator Certification Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        BSC / LAF certification log — cabinet type &times; downflow &amp; inflow velocity m/s &times;
        HEPA DOP/PAO leak test &times; particle-count ISO class &times; airflow alarm &times; UV lamp
        hours &times; smoke-pattern &times; sash interlock &amp; CAPA closure. Founder-gated view: cert
        verdicts, hospital scorecards, root-cause pareto, and regulatory-impact digest across NABH,
        CDSCO, ISO 14644 &amp; USP 800 surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Certification verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No certification checks logged yet."
          rowKey={(r, i) => String(r.cert_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital certification scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Cabinet type &times; ISO class matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No checks by cabinet type."
          rowKey={(r, i) => `${r.cabinet_type}-${r.particle_count_iso_class}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily certification trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.check_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk certification queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk cabinets."
          rowKey={(r, i) => `${r.cabinet_code}-${r.check_date}-${i}`}
        />
      </section>
    </main>
  );
}
